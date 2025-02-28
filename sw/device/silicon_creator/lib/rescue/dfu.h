// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_BOOT_LOG_H_
#define OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_BOOT_LOG_H_

#include <stdint.h>

#include "sw/device/silicon_creator/lib/boot_data.h"
#include "sw/device/silicon_creator/lib/drivers/usb.h"
#include "sw/device/silicon_creator/lib/rescue/rescue.h"

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
  usb_control_ctx_t ep0;
  rescue_state_t state;
  boot_data_t *bootdata;
  uint32_t expected_len;
  uint8_t status[6];
  uint8_t dfu_state;
  uint8_t dfu_error;
  uint8_t interface;
} dfu_ctx_t;

/**
 * Start a DFU transfer.
 *
 * @param ep The endpoint number.
 * @param data The buffer to send or receive into.
 * @param len The length of the buffer.
 * @param flags The direction or other attributes assocated with the transfer.
 */
void dfu_transport_data(dfu_ctx_t *ctx, void *data, size_t len,
                        usb_transfer_flags_t flags);

/**
 * Handle the transport's standard setupdata requests
 *
 * @param ctx A pointer to the transport's control context structure.
 * @param setup A pointer to the setupdata.
 * @return Result of handling the setupdata.
 */
rom_error_t dfu_transport_setupdata(usb_control_ctx_t *ctx,
                                    usb_setup_data_t *setup);

void dfu_transport_result(uint32_t result);

void dfu_protocol_handler(void *ctx, size_t ep, usb_transfer_flags_t flags,
                          void *data);

#ifdef __cplusplus
}
#endif

#endif  // OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_BOOT_LOG_H_
