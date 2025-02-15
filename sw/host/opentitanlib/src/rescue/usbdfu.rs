// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

use anyhow::{bail, Result};
use std::cell::{Cell, Ref, RefCell, RefMut};
use std::time::Duration;
use zerocopy::AsBytes;

use crate::app::TransportWrapper;
use crate::rescue::dfu::*;
use crate::rescue::{Rescue, RescueError, RescueMode, RescueParams};
use crate::util::usb::UsbBackend;

pub struct UsbDfu {
    usb: RefCell<Option<UsbBackend>>,
    interface: Cell<u8>,
    wait: Cell<bool>,
    params: RescueParams,
    reset_delay: Duration,
    enter_delay: Duration,
}

impl UsbDfu {
    const CLASS: u8 = 254;
    const SUBCLASS: u8 = 1;
    const PROTOCOL: u8 = 2;
    pub fn new(params: RescueParams) -> Self {
        UsbDfu {
            usb: RefCell::new(None),
            interface: Cell::default(),
            wait: Cell::default(),
            params,
            reset_delay: Duration::from_millis(50),
            enter_delay: Duration::from_secs(5),
        }
    }

    fn device(&self) -> Ref<'_, UsbBackend> {
        let device = self.usb.borrow();
        Ref::map(device, |d| d.as_ref().expect("device handle"))
    }

    fn device_mut(&self) -> RefMut<'_, UsbBackend> {
        let device = self.usb.borrow_mut();
        RefMut::map(device, |d| d.as_mut().expect("device handle"))
    }
}

impl Rescue for UsbDfu {
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
        let device = UsbBackend::from_interface_with_timeout(
            Self::CLASS,
            Self::SUBCLASS,
            Self::PROTOCOL,
            self.params.usb_serial.as_deref(),
            self.enter_delay,
        );
        log::info!("Rescue triggered; clearing trigger condition.");
        self.params.set_trigger(transport, false)?;
        let mut device = device?;

        let config = device.active_config_descriptor()?;
        for intf in config.interfaces() {
            for desc in intf.descriptors() {
                if desc.class_code() == 0xFE
                    && desc.sub_class_code() == 1
                    && desc.protocol_code() == 2
                {
                    device.claim_interface(intf.number())?;
                    self.interface.set(intf.number());
                    break;
                }
            }
        }
        self.usb.replace(Some(device));
        Ok(())
    }

    fn set_mode(&self, mode: RescueMode) -> Result<()> {
        let setting = match mode {
            // FIXME: the RescueMode to AltSetting values either need to be permanently fixed, or
            // the alt interfaces need to describe themselves via a string descriptor.
            RescueMode::Rescue => 0,
            RescueMode::RescueB => 1,
            RescueMode::DeviceId => 2,
            RescueMode::BootLog => 3,
            RescueMode::BootSvcReq => 4,
            RescueMode::BootSvcRsp => 4,
            RescueMode::OwnerBlock => 5,
            RescueMode::GetOwnerPage0 => 5,
            _ => bail!(RescueError::BadMode(format!(
                "mode {mode:?} not supported by DFU"
            ))),
        };

        let mut device = self.device_mut();
        log::info!("Mode {mode} is AltSetting {setting}");
        device.set_alternate_setting(self.interface.get(), setting)?;
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
        let usb = self.device();
        match usb.reset() {
            Ok(_) => {}
            Err(e) => log::warn!("USB reset: {e}"),
        }
        Ok(())
    }

    fn send(&self, data: &[u8]) -> Result<()> {
        for chunk in data.chunks(2048) {
            let _ = self.download(chunk)?;
            let status = loop {
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
        match status.state() {
            DfuState::Manifest => {
                if !self.wait.get() {
                    self.reboot()?;
                }
            }
            _ => {}
        }

        Ok(())
    }

    fn recv(&self) -> Result<Vec<u8>> {
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

impl DfuOperations for UsbDfu {
    fn download(&self, data: &[u8]) -> Result<usize> {
        let usb = self.device();
        usb.write_control(
            DfuRequestType::Out.into(),
            DfuRequest::DnLoad.into(),
            /*wValue=*/ 0,
            /*wIndex=*/ self.interface.get() as u16,
            data,
        )
    }

    fn upload(&self, data: &mut [u8]) -> Result<usize> {
        let usb = self.device();
        usb.read_control(
            DfuRequestType::In.into(),
            DfuRequest::UpLoad.into(),
            /*wValue=*/ 0,
            /*wIndex=*/ self.interface.get() as u16,
            data,
        )
    }

    fn get_state(&self) -> Result<DfuState> {
        let mut buffer = [0u8];
        let usb = self.device();
        usb.read_control(
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
        let usb = self.device();
        usb.read_control(
            DfuRequestType::In.into(),
            DfuRequest::GetStatus.into(),
            /*wValue=*/ 0,
            /*wIndex=*/ self.interface.get() as u16,
            status.as_bytes_mut(),
        )?;
        Ok(status)
    }

    fn clear_status(&self) -> Result<()> {
        let usb = self.device();
        let _ = usb.write_control(
            DfuRequestType::Out.into(),
            DfuRequest::ClrStatus.into(),
            /*wValue=*/ 0,
            /*wIndex=*/ self.interface.get() as u16,
            &[],
        )?;
        Ok(())
    }

    fn abort(&self) -> Result<()> {
        let usb = self.device();
        let _ = usb.write_control(
            DfuRequestType::Out.into(),
            DfuRequest::ClrStatus.into(),
            /*wValue=*/ 0,
            /*wIndex=*/ self.interface.get() as u16,
            &[],
        )?;
        Ok(())
    }
}
