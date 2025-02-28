// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <stdbool.h>
#include <stdint.h>

// #include "sw/device/lib/arch/device.h"
#include "sw/device/lib/base/macros.h"
#include "sw/device/silicon_creator/lib/drivers/rstmgr.h"
#include "sw/device/silicon_creator/lib/drivers/usb.h"
#include "sw/device/silicon_creator/lib/error.h"
#include "sw/device/silicon_creator/lib/rescue/dfu.h"

#include "hw/top_earlgrey/sw/autogen/top_earlgrey.h"

typedef struct rescue_mode_properties {
  uint32_t mode;
  bool dnload;
  bool upload;
} rescue_mode_properties_t;

static rescue_mode_properties_t mode_by_altsetting[] = {
    {kRescueModeFirmware, true, false},
    {kRescueModeFirmwareSlotB, true, false},
    {kRescueModeOpenTitanID, false, true},
    {kRescueModeBootLog, false, true},
    {kRescueModeBootSvcRsp, true, true},
    {kRescueModeOwnerPage0, true, true},
    //  { kRescueModeOwnerPage1, false, true },
};

static rom_error_t dfu_control(dfu_ctx_t *ctx, usb_setup_data_t *setup) {
  rom_error_t result = kErrorOk;
  if (setup->request <= kDfuReqAbort) {
    dfu_state_transition_t *tr =
        &dfu_state_table[setup->request][ctx->dfu_state];
    switch (tr->action) {
      case kDfuActionNone:
        ctx->dfu_state = tr->next[0];
        dfu_transport_data(ctx, NULL, 0, kUsbTransferFlagsIn);
        break;
      case kDfuActionStall:
        ctx->dfu_state = tr->next[0];
        result = kErrorUsbBadSetup;
        break;
      case kDfuActionCheckLen:
        ctx->dfu_state = tr->next[setup->length == 0 ? 0 : 1];
        if (setup->length <= sizeof(ctx->state.data) &&
            (setup->request == kDfuReqDnLoad ||
             setup->request == kDfuReqUpLoad)) {
          if (setup->request == kDfuReqDnLoad) {
            dfu_transport_data(ctx, ctx->state.data, setup->length,
                               setup->length == 0 ? kUsbTransferFlagsIn
                                                  : kUsbTransferFlagsOut);
          } else {
            usb_transfer_flags_t flags = kUsbTransferFlagsIn;
            size_t length = MIN(ctx->state.staged_len, setup->length);
            if (length < setup->length && length % 64 == 0)
              flags |= kUsbTransferFlagsShortIn;
            dfu_transport_data(ctx, ctx->state.data, length, flags);
          }
        } else {
          result = kErrorUsbBadSetup;
        }
        break;
      case kDfuActionStatusResponse:
        ctx->dfu_state = tr->next[0];
        ctx->status[0] = (uint8_t)ctx->dfu_error;
        ctx->status[1] = 100;  // milliseconds
        ctx->status[2] = 0;
        ctx->status[3] = 0;
        ctx->status[4] = (uint8_t)ctx->dfu_state;
        ctx->status[5] = 0;
        dfu_transport_data(ctx, ctx->status, sizeof(ctx->status),
                           kUsbTransferFlagsIn);
        break;
      case kDfuActionStateResponse:
        ctx->dfu_state = tr->next[0];
        dfu_transport_data(ctx, &ctx->dfu_state, 1, kUsbTransferFlagsIn);
        break;
      case kDfuActionClearError:
        ctx->dfu_state = tr->next[0];
        ctx->dfu_error = kDfuErrOk;
        dfu_transport_data(ctx, NULL, 0, kUsbTransferFlagsIn);
        break;
    }
  } else {
    ctx->dfu_state = kDfuStateError;
    ctx->dfu_error = kDfuErrUnknown;
    result = kErrorUsbBadSetup;
  }
  return result;
}

static rom_error_t validate_mode(uint32_t setting, rescue_state_t *state,
                                 boot_data_t *bootdata) {
  // Allow the `setting` to be either an index or a FourCC code.
  if (setting >= ARRAYSIZE(mode_by_altsetting)) {
    size_t i = 0;
    for (; i < ARRAYSIZE(mode_by_altsetting); ++i) {
      if (setting == mode_by_altsetting[i].mode) {
        setting = i;
        break;
      }
    }
    if (i == ARRAYSIZE(mode_by_altsetting)) {
      return kErrorRescueBadMode;
    }
  }
  rescue_mode_properties_t *mode = &mode_by_altsetting[setting];
  rom_error_t error2 = kErrorOk;
  rom_error_t error = rescue_validate_mode(mode->mode, state, bootdata);
  if (error == kErrorOk && mode->upload) {
    rescue_send_handler(state, bootdata);
  }
  if (mode->mode == kRescueModeBootSvcRsp) {
    error2 = rescue_validate_mode(kRescueModeBootSvcReq, state, bootdata);
  } else if (mode->mode == kRescueModeOwnerPage0) {
    error2 = rescue_validate_mode(kRescueModeOwnerBlock, state, bootdata);
  }

  if (error == kErrorOk || error2 == kErrorOk) {
    return kErrorOk;
  }
  return kErrorRescueBadMode;
}

void dfu_protocol_handler(void *_ctx, size_t ep, usb_transfer_flags_t flags,
                          void *data) {
  dfu_ctx_t *ctx = (dfu_ctx_t *)_ctx;
  if (flags & kUsbTransferFlagsSetupData) {
    usb_setup_data_t *setup = (usb_setup_data_t *)data;

    rom_error_t error = kErrorOk;
    if ((setup->request_type & kUsbReqTypeTypeMask) == kUsbReqTypeClass) {
      error = dfu_control(ctx, setup);
    } else if ((setup->request_type & kUsbReqTypeTypeMask) ==
               kUsbReqTypeVendor) {
      switch (setup->request) {
        // Proprietary vendor version of SetInterface that constructs the
        // FourCC from the value and index fields.
        case kUsbSetupReqSetInterface: {
          uint32_t mode = ((uint32_t)setup->value << 16) | setup->index;
          if (validate_mode(mode, &ctx->state, ctx->bootdata) == kErrorOk) {
            dfu_transport_data(ctx, NULL, 0, kUsbTransferFlagsIn);
          } else {
            error = kErrorUsbBadSetup;
          }
        } break;
        default:
          error = kErrorUsbBadSetup;
      }
    } else if ((setup->request_type & kUsbReqTypeRecipientMask) ==
               kUsbReqTypeInterface) {
      switch (setup->request) {
        case kUsbSetupReqSetInterface:
          if (validate_mode(setup->value, &ctx->state, ctx->bootdata) ==
              kErrorOk) {
            ctx->interface = (uint8_t)setup->value;
            dfu_transport_data(ctx, NULL, 0, kUsbTransferFlagsIn);
          } else {
            error = kErrorUsbBadSetup;
          }
          break;
        case kUsbSetupReqGetInterface:
          dfu_transport_data(ctx, &ctx->interface, sizeof(ctx->interface),
                             kUsbTransferFlagsIn);
          break;
        default:
          error = kErrorUsbBadSetup;
      }
    } else {
      error = dfu_transport_setupdata(&ctx->ep0, setup);
    }
    dfu_transport_result(error);
  }
  if (flags & kUsbTransferFlagsDone) {
    if (ctx->ep0.flags & kUsbControlFlagsPendingAddress) {
      ctx->ep0.flags &= ~(unsigned)kUsbControlFlagsPendingAddress;
      ctx->ep0.device_address = ctx->ep0.next.device_address;
      usb_set_address(ctx->ep0.device_address);
    }
    if (ctx->ep0.flags & kUsbControlFlagsPendingConfig) {
      ctx->ep0.flags &= ~(unsigned)kUsbControlFlagsPendingConfig;
      ctx->ep0.configuration = ctx->ep0.next.configuration;
    }
  }
  if (flags & kUsbTransferFlagsDone) {
    int length = *(int *)data;
    if (ctx->dfu_state == kDfuStateDnLoadSync) {
      ctx->state.offset = (uint32_t)length;
      while (ctx->state.offset < sizeof(ctx->state.data)) {
        ctx->state.data[ctx->state.offset++] = 0xFF;
      }
      rom_error_t error = rescue_recv_handler(&ctx->state, ctx->bootdata);
      dbg_printf("recv_handler %x\r\n", error);
      switch (error) {
        case kErrorOk:
          ctx->dfu_error = kDfuErrOk;
          break;
        default:
          ctx->dfu_error = kDfuErrVendor;
      }
      ctx->dfu_state = kDfuStateDnLoadIdle;
    } else if (ctx->dfu_state == kDfuStateUpLoadIdle) {
      if (length < 2048) {
        ctx->dfu_state = kDfuStateIdle;
      }
      ctx->state.staged_len = 0;
    }
  }

  if (flags & kUsbTransferFlagsReset) {
    dfu_state_transition_t *tr =
        &dfu_state_table[kDfuReqBusReset][ctx->dfu_state];
    if (tr->action == kDfuActionReset) {
      rstmgr_reset();
    } else {
      validate_mode(0, &ctx->state, ctx->bootdata);
      ctx->ep0.flags = 0;
      ctx->ep0.device_address = 0;
      ctx->ep0.configuration = 0;
    }
  }
}
