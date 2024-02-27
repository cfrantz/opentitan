// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_LIB_TESTING_HEXSTR_H_
#define OPENTITAN_SW_DEVICE_LIB_TESTING_HEXSTR_H_

#include <stdint.h>

#include "sw/device/lib/base/status.h"

#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus

status_t hexstr_encode(char *dst, size_t dst_size, const void *src,
                       size_t src_size);

status_t hexstr_decode(void *dst, size_t dst_size, const char *src);

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  // OPENTITAN_SW_DEVICE_LIB_TESTING_HEXSTR_H_
