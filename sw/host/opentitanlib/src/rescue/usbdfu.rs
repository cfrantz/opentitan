// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

use anyhow::{bail,Result};
use std::cell::{Cell, RefCell};
use std::time::Duration;

use crate::app::TransportWrapper;
use crate::rescue::{Rescue, RescueError, RescueMode};
use crate::util::usb::UsbBackend;
use crate::uart::console::UartConsole;
use crate::rescue::{Rescue, RescueParams, RescueError};

pub struct UsbDfu {
    usb: RefCell<Option<UsbBackend>>,
    interface: Cell<u8>,
    params: RescueParams,
    reset_delay: Duration,
    enter_delay: Duration,
}

impl UsbDfu {
    pub fn new(params: RescueParams) -> Self {
        UsbDfu {
            usb: None,
            interface: Cell::default(),
            params,
            reset_delay: Duration::from_millis(50),
            enter_delay: Duration::from_secs(5),
        }
    }

    fn device(&self) -> Ref<'_, UsbBackend> {
        let device = self.usb.borrow();
        Ref::map(device, |d| d.as_ref().expect("device handle"))
    }
}

impl Rescue for RescueSerial {
    fn enter(&self, transport: &TransportWrapper, reset_target: bool) -> Result<()> {
        log::info!("Setting {:?}({}) to trigger rescue mode.", self.params.trigger, self.params.value);
        self.params.set_trigger(transport, true)?;
        if reset_target {
            transport.reset_target(self.reset_delay, /*clear_uart=*/ true)?;
        }
        let device = UsbBackend::from_interface_with_timeout(0xFE, 0, 2, self.enter_delay)?;
        log::info!("Rescue triggered; clearing trigger condition.");
        self.params.set_trigger(transport, false)?;

        let config = device.active_config_descriptor()?;
        for intf in config.interfaces() {
            for desc in intf.descriptors() {
                if desc.class_code() == 0xFE
                    && desc.sub_class_code() == 0
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
        let setting = match mode  {
            RescueMode::Rescue => 0,
            RescueMode::RescueB => 1,
            RescueMode::DeviceId => 2,
            RescueMode::BootLog => 3,
            RescueMode::BootSvcReq => 4,
            RescueMode::BootSvcRsp => 4,
            RescueMode::OwnerBlock => 5,
            RescueMode::GetOwnerPage0 => 5,
            _ => bail!(RescueError::BadMode(format!("mode {mode:?} not supported by usb-dfu"))),
        };

        let device = self.device();
        device.set_alternate_setting(self.interface.get(), setting)?;
        Ok(())
    }

    fn reboot(&self) -> Result<()> {
        unimplemented!();
    }

    fn send(&self, data: &[u8]) -> Result<()> {
        let xm = Xmodem::new();
        xm.send(&*self.uart, data)?;
        Ok(())
    }

    fn recv(&self) -> Result<Vec<u8>> {
        let mut data = Vec::new();
        let xm = Xmodem::new();
        xm.receive(&*self.uart, &mut data)?;
        Ok(data)
    }
}
