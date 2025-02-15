// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

use crate::with_unknown;

with_unknown! {
    enum DfuState: u8 [default = Self::AppIdle] {
      AppIdle = 0,
      AppDetach,
      Idle,
      DnLoadSync,
      DnLoadBusy,
      DnLoadIdle,
      ManifestSync,
      Manifest,
      ManifestWaitReset,
      UpLoadIdle,
      Error,
    }

    enum DfuError: u8 [default = Self::Ok] {
      Ok = 0,
      Target,
      File,
      Write,
      Erase,
      CheckErased,
      Prog,
      Verify,
      Address,
      NotDone,
      Firmware,
      Vendor,
      UsbReset,
      PowerOnReset,
      Unknown,
      StalledPkt,
    }

    enum DfuRequest: u8 {
      Detach = 0,
      DnLoad,
      UpLoad,
      GetStatus,
      ClrStatus,
      GetState,
      Abort,
      BusReset,
    }
}

struct DfuStatus {
    status: DfuError,
    poll_timeout: [u8; 3],
    state: DfuState,
    string: u8
}

impl std::error::Error for DfuError {}

impl DfuStatus {
    pub fn status(&self) -> std::result::Result<(), DfuError> {
        match self.status {
            DfuError::Ok => Ok(()),
            e => Err(e),
        }
    }
    pub fn poll_timeout(&self) -> u32 {
        u32::from_le_bytes([ poll_timeout[0], poll_timeout[1], poll_timeout[2], 0])
    }
    pub fn state(&self) -> DfuState { self.state }
    pub fn string(&self) -> u8 { self.string }
}

