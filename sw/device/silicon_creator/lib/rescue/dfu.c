// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/silicon_creator/lib/rescue/dfu.h"

#include <stdbool.h>
#include <stdint.h>

#include "sw/device/lib/base/macros.h"
#include "sw/device/silicon_creator/lib/drivers/rstmgr.h"
#include "sw/device/silicon_creator/lib/drivers/usb.h"
#include "sw/device/silicon_creator/lib/error.h"

#include "hw/top_earlgrey/sw/autogen/top_earlgrey.h"

typedef struct rescue_mode_properties {
  uint32_t mode;
  bool dnload;
  bool upload;
} rescue_mode_properties_t;

static const rescue_mode_properties_t mode_by_altsetting[] = {
    {kRescueModeFirmware, true, false},
    {kRescueModeFirmwareSlotB, true, false},
    {kRescueModeOpenTitanID, false, true},
    {kRescueModeBootLog, false, true},
    {kRescueModeBootSvcRsp, true, true},
    {kRescueModeOwnerPage0, true, true},
    //{ kRescueModeOwnerPage1, false, true },
};

static rom_error_t dfu_control(dfu_ctx_t *ctx, usb_setup_data_t *setup) {
  rom_error_t result = kErrorOk;
  if (setup->request <= kDfuReqAbort) {
    // Determine which state transition is relevant.
    dfu_state_transition_t *tr =
        &dfu_state_table[setup->request][ctx->dfu_state];

    // Carry out the action for this state transition.
    switch (tr->action) {
      case kDfuActionNone:
        // No action: move to the next state and ack the transaction.
        ctx->dfu_state = tr->next[0];
        dfu_transport_data(ctx, NULL, 0, kUsbTransactionFlagsIn);
        break;
      case kDfuActionStall:
        // Stall: move to the next state and stall the transport.
        ctx->dfu_state = tr->next[0];
        result = kErrorUsbBadSetup;
        break;
      case kDfuActionCheckLen:
        // Check the length and download/upload.
        ctx->dfu_state = tr->next[setup->length == 0 ? 0 : 1];
        // Length is good and the request is either upload/download.
        if (setup->length <= sizeof(ctx->state.data) &&
            (setup->request == kDfuReqDnLoad ||
             setup->request == kDfuReqUpLoad)) {
          if (setup->request == kDfuReqDnLoad) {
            // If its a download (transfer to opentitan), perform the transfer
            // into the rescue state buffer. For a zero-length request, simply
            // ACK with a zero-length packet.
            dfu_transport_data(ctx, ctx->state.data, setup->length,
                               setup->length == 0 ? kUsbTransactionFlagsIn : 0);
          } else {
            // If its an upload (transfer to the host), perform the transfer
            // from the rescue state buffer. A prior `SetInterface` command will
            // have staged the requested content into the buffer.
            usb_transaction_flags_t flags = kUsbTransactionFlagsIn;
            size_t length = (size_t)MIN(ctx->state.staged_len, setup->length);
            if (length < setup->length && length % 64 == 0)
              flags |= kUsbTransactionFlagsShortIn;
            dfu_transport_data(ctx, ctx->state.data, length, flags);
          }
        } else {
          result = kErrorUsbBadSetup;
        }
        break;
      case kDfuActionStatusResponse:
        // Send a status response to the host.
        ctx->dfu_state = tr->next[0];
        ctx->status[0] = (uint8_t)ctx->dfu_error;
        ctx->status[1] = 100;  // poll us every 100 milliseconds.
        ctx->status[2] = 0;
        ctx->status[3] = 0;
        ctx->status[4] = (uint8_t)ctx->dfu_state;
        ctx->status[5] = 0;
        dfu_transport_data(ctx, ctx->status, sizeof(ctx->status),
                           kUsbTransactionFlagsIn);
        break;
      case kDfuActionStateResponse:
        // Send our current DFU state to the host.
        ctx->dfu_state = tr->next[0];
        dfu_transport_data(ctx, &ctx->dfu_state, 1, kUsbTransactionFlagsIn);
        break;
      case kDfuActionClearError:
        // Clear the current error.
        ctx->dfu_state = tr->next[0];
        ctx->dfu_error = kDfuErrOk;
        dfu_transport_data(ctx, NULL, 0, kUsbTransactionFlagsIn);
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
  // The the integer value is less than the arraysize, then its clearly an
  // index.
  if (setting >= ARRAYSIZE(mode_by_altsetting)) {
    // All of the FourCC codes are going to be greater than any index.  Search
    // the array for a matching FourCC code and use the index as the setting.
    size_t i = 0;
    for (; i < ARRAYSIZE(mode_by_altsetting); ++i) {
      if (setting == mode_by_altsetting[i].mode) {
        setting = i;
        break;
      }
    }
  }
  if (setting >= ARRAYSIZE(mode_by_altsetting)) {
    // Setting not found; Bad mode.
    return kErrorRescueBadMode;
  }

  // The UART version of the protocol has to distinguish between send and recv
  // targets for the same service (e.g. boot service has a request and a
  // response mode).  Since DFU supports upload and download operations to the
  // same target, we handle the "send" services first to stage data into the
  // rescue buffer.
  const rescue_mode_properties_t *mode = &mode_by_altsetting[setting];
  rom_error_t error2 = kErrorOk;
  rom_error_t error = rescue_validate_mode(mode->mode, state, bootdata);
  if (error == kErrorOk && mode->upload) {
    // DFU upload means send to the host.  We stage the data that would
    // be sent to the rescue buffer.
    rescue_send_handler(state, bootdata);
  }
  // BootSvc and OwnerPage are also recv (from the host) services.  Make sure
  // we're set up to process a DFU download for those services.
  if (mode->mode == kRescueModeBootSvcRsp) {
    error2 = rescue_validate_mode(kRescueModeBootSvcReq, state, bootdata);
  } else if (mode->mode == kRescueModeOwnerPage0) {
    error2 = rescue_validate_mode(kRescueModeOwnerBlock, state, bootdata);
  }

  if (error == kErrorOk || error2 == kErrorOk) {
    // If either the send or recv mode is ok, then setting the mode is ok.
    // If only one is Ok, the send or recv handler will report the error when we
    // try an unauthorized operation.
    return kErrorOk;
  }
  // If neither is Ok, the report bad mode.
  return kErrorRescueBadMode;
}

void dfu_protocol_handler(void *_ctx, uint8_t ep, usb_transaction_flags_t flags,
                          void *data) {
  dfu_ctx_t *ctx = (dfu_ctx_t *)_ctx;
  OT_DISCARD(ep);

  // Handle event callbacks from the underlying transport (e.g. USB).

  // If its SETUPDATA, its a USB or DFU request.
  if (flags & kUsbTransactionFlagsSetupData) {
    usb_setup_data_t *setup = (usb_setup_data_t *)data;

    rom_error_t error = kErrorOk;
    if ((setup->request_type & kUsbReqTypeTypeMask) == kUsbReqTypeClass) {
      // If its a class-level request, call the DFU control function.
      error = dfu_control(ctx, setup);
    } else if ((setup->request_type & kUsbReqTypeTypeMask) ==
               kUsbReqTypeVendor) {
      // If its a proprietary vendor request, we handle it here.
      switch (setup->request) {
        // Proprietary vendor version of SetInterface that constructs the
        // FourCC from the value and index fields.
        case kUsbSetupReqSetInterface: {
          uint32_t mode = ((uint32_t)setup->value << 16) | setup->index;
          if (validate_mode(mode, &ctx->state, ctx->bootdata) == kErrorOk) {
            dfu_transport_data(ctx, NULL, 0, kUsbTransactionFlagsIn);
          } else {
            error = kErrorUsbBadSetup;
          }
        } break;
        default:
          error = kErrorUsbBadSetup;
      }
    } else if ((setup->request_type & kUsbReqTypeRecipientMask) ==
               kUsbReqTypeInterface) {
      // If its an interface-level request, we handle it here.  These requests
      // will be {Set,Get}Interface.  We use interface altsettings to control
      // which services rescue is communicating with.
      switch (setup->request) {
        case kUsbSetupReqSetInterface:
          if (validate_mode(setup->value, &ctx->state, ctx->bootdata) ==
              kErrorOk) {
            ctx->interface = (uint8_t)setup->value;
            dfu_transport_data(ctx, NULL, 0, kUsbTransactionFlagsIn);
          } else {
            error = kErrorUsbBadSetup;
          }
          break;
        case kUsbSetupReqGetInterface:
          dfu_transport_data(ctx, &ctx->interface, sizeof(ctx->interface),
                             kUsbTransactionFlagsIn);
          break;
        default:
          error = kErrorUsbBadSetup;
      }
    } else {
      // Otherwise, all other requests get mapped to the standard control
      // endpoint function.
      error = dfu_transport_setupdata(ctx, setup);
      // Take care of the SetConfiguration command.
      if (ctx->ep0.flags & kUsbControlFlagsPendingConfig) {
        ctx->ep0.flags &= ~(unsigned)kUsbControlFlagsPendingConfig;
        ctx->ep0.configuration = ctx->ep0.next.configuration;
        dfu_transport_data(ctx, NULL, 0, kUsbTransactionFlagsIn);
      }
    }
    dfu_transport_result(ctx, error);
  }

  // If we completed a transaction, process the completion.
  if (flags & kUsbTransactionFlagsDone) {
    // Take care of the SetAddress command.
    if (ctx->ep0.flags & kUsbControlFlagsPendingAddress) {
      ctx->ep0.flags &= ~(unsigned)kUsbControlFlagsPendingAddress;
      ctx->ep0.device_address = ctx->ep0.next.device_address;
      usb_set_address(ctx->ep0.device_address);
    }

    int length = *(int *)data;
    if (ctx->dfu_state == kDfuStateDnLoadSync) {
      // If we're in the DnLoadSync state and we completed a transfer, that
      // means the rescue buffer has data to process.
      ctx->state.offset = (uint32_t)length;
      while (ctx->state.offset < sizeof(ctx->state.data)) {
        // Make sure the full buffer is filled.  Fill unused space with 0xFF.
        ctx->state.data[ctx->state.offset++] = 0xFF;
      }
      // Pass the rescue buffer to the rescue receive handler.
      rom_error_t error = rescue_recv_handler(&ctx->state, ctx->bootdata);
      switch (error) {
        case kErrorOk:
          ctx->dfu_error = kDfuErrOk;
          break;
        default:
          ctx->dfu_error = kDfuErrVendor;
      }
      // Back to DnLoadIdle state.
      ctx->dfu_state = kDfuStateDnLoadIdle;
    } else if (ctx->dfu_state == kDfuStateUpLoadIdle) {
      if (length < 2048) {
        ctx->dfu_state = kDfuStateIdle;
      }
      // The amount of staged data is now zero.
      ctx->state.staged_len = 0;
    }
  }

  if (flags & kUsbTransactionFlagsReset) {
    // A USB reset after we've been enumerated means software reset.
    if (ctx->ep0.device_address && ctx->ep0.configuration) {
      rstmgr_reset();
    }
  }
}
