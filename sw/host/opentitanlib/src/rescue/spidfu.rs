// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

use anyhow::{bail, Result};
use std::cell::{Cell, RefCell};
use std::time::{Duration, Instant};
use std::rc::Rc;
use zerocopy::AsBytes;

use crate::app::TransportWrapper;
use crate::rescue::dfu::*;
use crate::rescue::{Rescue, RescueError, RescueMode, RescueParams};
use crate::io::spi::{Target};
use crate::spiflash::SpiFlash;
use crate::chip::rom_error::RomError;

#[repr(C)]
#[derive(Default, Debug, AsBytes)]
struct SetupData {
    request_type: u8,
    request: u8,
    value: u16,
    index: u16,
    length: u16,
}

pub struct SpiDfu {
    spi: Rc<dyn Target>,
    flash: RefCell<SpiFlash>,
    interface: Cell<u8>,
    wait: Cell<bool>,
    params: RescueParams,
    reset_delay: Duration,
    enter_delay: Duration,
}

impl SpiDfu {
    const MAILBOX: u32 = 0x00FF_F000;
    pub fn new(spi: Rc<dyn Target>, params: RescueParams) -> Self {
        SpiDfu {
            spi,
            flash: RefCell::default(),
            interface: Cell::default(),
            wait: Cell::default(),
            params,
            reset_delay: Duration::from_millis(50),
            enter_delay: Duration::from_secs(5),
        }
    }

    fn wait_for_device(spi: &dyn Target, timeout: Duration) -> Result<SpiFlash> {
        let deadline = Instant::now() + timeout;
        loop {
            match SpiFlash::from_spi(spi) {
                Ok(flash) => return Ok(flash),
                Err(e) => {
                    if Instant::now() < deadline {
                        std::thread::sleep(Duration::from_millis(100));
                    } else {
                        return Err(e);
                    }
                }
            }
        }
    }


    fn write_control(
        &self,
        request_type: u8,
        request: u8,
        value: u16,
        index: u16,
        data: &[u8],
    ) -> Result<usize> {
        let setup = SetupData {
            request_type,
            request,
            value,
            index,
            length: data.len().try_into()?,
        };
        let flash = self.flash.borrow();
        log::info!("write_control: {setup:x?}");
        flash.program(&*self.spi, Self::MAILBOX, setup.as_bytes())?;

        let mut result = [0u8; 4];
        flash.read(&*self.spi, Self::MAILBOX, &mut result)?;
        log::info!("write_control result: {result:x?}");
        let _ = Result::<(), RomError>::from(RomError(u32::from_le_bytes(result)))?;

        flash.program(&*self.spi, 0, data)?;
        Ok(data.len())
    }

    fn read_control(
        &self,
        request_type: u8,
        request: u8,
        value: u16,
        index: u16,
        data: &mut [u8],
    ) -> Result<usize> {
        let setup = SetupData {
            request_type,
            request,
            value,
            index,
            length: data.len().try_into()?,
        };
        let flash = self.flash.borrow();
        log::info!("read_control: {setup:x?}");
        flash.program(&*self.spi, Self::MAILBOX, setup.as_bytes())?;

        let mut result = [0u8; 4];
        flash.read(&*self.spi, Self::MAILBOX, &mut result)?;
        log::info!("read_control result: {result:x?}");
        let _ = Result::<(), RomError>::from(RomError(u32::from_le_bytes(result)))?;

        flash.read(&*self.spi, 0, data)?;
        Ok(data.len())
    }

}

impl Rescue for SpiDfu {
    fn enter(&self, transport: &TransportWrapper, reset_target: bool) -> Result<()> {
        log::info!(
            "Setting {:?}({}) to trigger rescue mode.",
            self.params.trigger,
            self.params.value
        );
        self.params.set_trigger(transport, true)?;
        if reset_target {
            transport.reset_target(self.reset_delay, /*clear_uart=*/ false)?;
            std::thread::sleep(Duration::from_millis(100));
        }

        let flash = Self::wait_for_device(&*self.spi, self.enter_delay);
        log::info!("Rescue triggered; clearing trigger condition.");
        self.params.set_trigger(transport, false)?;
        let mut flash = flash?;
        flash.set_address_mode_auto(&*self.spi)?;
        self.flash.replace(flash);
        Ok(())
    }

    fn set_mode(&self, mode: RescueMode) -> Result<()> {
        let setting = match mode {
            // FIXME: the RescueMode to AltSetting values either need to be permanently fixed, or
            // the alt interfaces need to describe themselves via a string descriptor.
            RescueMode::Rescue => RescueMode::Rescue,
            RescueMode::RescueB => RescueMode::RescueB,
            RescueMode::DeviceId => RescueMode::DeviceId,
            RescueMode::BootLog => RescueMode::BootLog,
            RescueMode::BootSvcReq => RescueMode::BootSvcRsp,
            RescueMode::BootSvcRsp => RescueMode::BootSvcRsp,
            RescueMode::OwnerBlock => RescueMode::GetOwnerPage0,
            RescueMode::GetOwnerPage0 => RescueMode::GetOwnerPage0,
            _ => bail!(RescueError::BadMode(format!(
                "mode {mode:?} not supported by DFU"
            ))),
        };

        log::info!("Mode {mode} is AltSetting {setting}");
        let setting = u32::from(setting);
        self.write_control(
            0x40,
            0x0b,
            (setting >> 16) as u16,
            setting as u16,
            &[],
        )?;
        Ok(())
    }

    fn set_speed(&self, _speed: u32) -> Result<u32> {
        log::warn!("set_speed is not implemented for DFU");
        Ok(0)
    }

    fn wait(&self) -> Result<()> {
        self.wait.set(true);
        Ok(())
    }

    fn reboot(&self) -> Result<()> {
        log::info!("Reboot");
        SpiFlash::chip_reset(&*self.spi)?;
        Ok(())
    }

    fn send(&self, data: &[u8]) -> Result<()> {
        log::info!("Send");
        for chunk in data.chunks(2048) {
            log::info!("download");
            let _ = self.download(chunk)?;
            let status = loop {
                log::info!("get_status");
                let status = self.get_status()?;
                match status.state() {
                    DfuState::DnLoadIdle | DfuState::Error => {
                        break status;
                    }
                    _ => {
                        std::thread::sleep(Duration::from_millis(status.poll_timeout() as u64));
                    }
                }
            };
            status.status()?;
        }
        // Send a zero-length chunk to signal the end.
        let _ = self.download(&[])?;
        let status = self.get_status()?;
        log::warn!("State after DFU download: {}", status.state());
        if status.state() == DfuState::Manifest && !self.wait.get() {
            self.reboot()?;
        }

        Ok(())
    }

    fn recv(&self) -> Result<Vec<u8>> {
        log::info!("Recv");
        let mut data = vec![0u8; 2048];
        /*
         * FIXME: what am I supposed to do here?
         * The spec seems to indicate that I should keep performing `upload` until I get back a
         * short or zero length packet.
        let mut offset = 0;
        loop {
            log::info!("upload at {offset}");
            let length = self.upload(&mut data[offset..])?;
            if length == 0 || length < data.len() - offset {
                break;
            }
            offset += length;
        }
        */
        self.upload(&mut data)?;
        Ok(data)
    }
}

impl DfuOperations for SpiDfu {
    fn download(&self, data: &[u8]) -> Result<usize> {
        self.write_control(
            DfuRequestType::Out.into(),
            DfuRequest::DnLoad.into(),
            /*wValue=*/ 0,
            /*wIndex=*/ self.interface.get() as u16,
            data,
        )
    }

    fn upload(&self, data: &mut [u8]) -> Result<usize> {
        self.read_control(
            DfuRequestType::In.into(),
            DfuRequest::UpLoad.into(),
            /*wValue=*/ 0,
            /*wIndex=*/ self.interface.get() as u16,
            data,
        )
    }

    fn get_state(&self) -> Result<DfuState> {
        let mut buffer = [0u8];
        self.read_control(
            DfuRequestType::In.into(),
            DfuRequest::GetState.into(),
            /*wValue=*/ 0,
            /*wIndex=*/ self.interface.get() as u16,
            &mut buffer,
        )?;
        Ok(DfuState(buffer[0]))
    }

    fn get_status(&self) -> Result<DfuStatus> {
        let mut status = DfuStatus::default();
        self.read_control(
            DfuRequestType::In.into(),
            DfuRequest::GetStatus.into(),
            /*wValue=*/ 0,
            /*wIndex=*/ self.interface.get() as u16,
            status.as_bytes_mut(),
        )?;
        Ok(status)
    }

    fn clear_status(&self) -> Result<()> {
        self.write_control(
            DfuRequestType::Out.into(),
            DfuRequest::ClrStatus.into(),
            /*wValue=*/ 0,
            /*wIndex=*/ self.interface.get() as u16,
            &[],
        )?;
        Ok(())
    }

    fn abort(&self) -> Result<()> {
        self.write_control(
            DfuRequestType::Out.into(),
            DfuRequest::ClrStatus.into(),
            /*wValue=*/ 0,
            /*wIndex=*/ self.interface.get() as u16,
            &[],
        )?;
        Ok(())
    }
}
