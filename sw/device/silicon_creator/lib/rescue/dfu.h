// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_BOOT_LOG_H_
#define OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_BOOT_LOG_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum dfu_state {
  kDfuStateAppIdle = 0,
  kDfuStateAppDetach,
  kDfuStateIdle,
  kDfuStateDnLoadSync,
  kDfuStateDnLoadBusy,
  kDfuStateDnLoadIdle,
  kDfuStateManifestSync,
  kDfuStateManifest,
  kDfuStateManifestWaitReset,
  kDfuStateUpLoadIdle,
  kDfuStateError,
  kDfuStateTotalLength,
} dfu_state_t;

typedef enum dfu_err {
  kDfuErrOk = 0,
  kDfuErrTarget,
  kDfuErrFile,
  kDfuErrWrite,
  kDfuErrErase,
  kDfuErrCheckErased,
  kDfuErrProg,
  kDfuErrVerify,
  kDfuErrAddress,
  kDfuErrNotDone,
  kDfuErrFirmware,
  kDfuErrVendor,
  kDfuErrUsbReset,
  kDfuErrPowerOnReset,
  kDfuErrUnknown,
  kDfuErrStalledPkt,
} dfu_err_t;

typedef enum dfu_req {
  kDfuReqDetach = 0,
  kDfuReqDnLoad,
  kDfuReqUpLoad,
  kDfuReqGetStatus,
  kDfuReqClrStatus,
  kDfuReqGetState,
  kDfuReqAbort,
  kDfuReqBusReset,
  kDfuReqTotalLength,
} dfu_req_t;

typedef enum dfu_action_t {
  kDfuActionNone = 0,
  kDfuActionStall,
  kDfuActionCheckLen,
  kDfuActionStatusResponse,
  kDfuActionStateResponse,
  kDfuActionClearError,
  kDfuActionReset,
} dfu_action_t;

typedef struct dfu_state_transition {
  uint8_t action;
  uint8_t next[2];
} dfu_state_transition_t;

extern dfu_state_transition_t dfu_state_table[kDfuReqTotalLength]
                                             [kDfuStateTotalLength];

typedef struct dfu_ctx {
  dfu_state_t state;
  dfu_err_t error;
  uint8_t status[6];
  uint8_t _pad[2];
  uint8_t buffer[2048];
} dfu_ctx_t;

#ifdef __cplusplus
}
#endif

#endif  // OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_BOOT_LOG_H_
