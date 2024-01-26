// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_SILICON_CREATOR_ROM_EXT_RESCUE_H_
#define OPENTITAN_SW_DEVICE_SILICON_CREATOR_ROM_EXT_RESCUE_H_

#include <stdint.h>

#include "sw/device/lib/base/hardened.h"
#include "sw/device/silicon_creator/lib/error.h"

enum {
    // Rescue is signalled by asserting serial break to the UART for at least
    // 4 byte periods.  At 115200 bps, one byte period is about 87us; four is
    // about 348us.  We'll wait for 350.
    kRescueDetectTime = 350,
};

/**
 * Whether a ROM_EXT rescue was requested.
 */
hardened_bool_t rescue_requested(void);

rom_error_t rescue_protocol(void);

#endif  // OPENTITAN_SW_DEVICE_SILICON_CREATOR_ROM_EXT_RESCUE_H_
