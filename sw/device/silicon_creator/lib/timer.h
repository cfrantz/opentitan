// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_TIMER_H_
#define OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_TIMER_H_

#include <stdint.h>

// Initialize the timer for 1us ticks, reset to zero and start timer.
void timer_init(void);

// The the low 32-bits of the timer value.
uint32_t timer_get(void);

#endif  // OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_TIMER_H_
