// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

use anyhow::Result;
use clap::Args;
use opentitanlib::io::uart::UartParams;
use serde_annotate::Annotate;
use std::any::Any;

use opentitanlib::app::command::CommandDispatch;
use opentitanlib::app::TransportWrapper;
use opentitanlib::bootstrap::xmodem::Xmodem;

/// Bootstrap the target device.
#[derive(Debug, Args)]
pub struct XmodemCommand {
    #[command(flatten)]
    params: UartParams,
    #[arg(value_name = "FILE")]
    filename: String,
}

impl CommandDispatch for XmodemCommand {
    fn run(
        &self,
        _context: &dyn Any,
        transport: &TransportWrapper,
    ) -> Result<Option<Box<dyn Annotate>>> {
        let payload = std::fs::read(&self.filename)?;
        let xmodem = Xmodem::new();
        let uart = self.params.create(transport)?;
        uart.clear_rx_buffer()?;
        xmodem.send(&*uart, &*payload)?;
        Ok(None)
    }
}
