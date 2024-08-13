// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#![no_main]
#![no_std]
use core::fmt::Write;
use libtock::console::Console;
use libtock::ipc::{Ipc, IpcCallback};
use libtock::runtime::{set_main, stack_size};
use libtock::alarm::{Alarm, Milliseconds};

set_main!(main);
stack_size!(0x400);

static mut fred: [u8; 4] = *b"fred";

fn main() {
    if Ipc::exists() {
        write!(Console::writer(), "IPC exists!\r\n").unwrap();
        let x = Ipc::discover("hello").unwrap();
        unsafe {
            Ipc::share(x, &mut fred).unwrap();
        }
        Ipc::notify_service(x);
    } else {
        write!(Console::writer(), "no IPC...\r\n").unwrap();
    }
    loop {
        Alarm::sleep_for(Milliseconds(500)).unwrap();
        write!(Console::writer(), "Goodbye world!!\r\n").unwrap();
    }
    // opentitan_functest's default test harness looks for `PASS` or `FAIL` in
    // the test output to determine the test result.
    //write!(Console::writer(), "PASS!\r\n").unwrap();
}
