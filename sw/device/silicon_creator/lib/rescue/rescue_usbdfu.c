// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <stdbool.h>
#include <stdint.h>

#include "sw/device/lib/arch/device.h"
#include "sw/device/lib/base/macros.h"
#include "sw/device/silicon_creator/lib/rescue/dfu.h"
#include "sw/device/silicon_creator/lib/drivers/lifecycle.h"
#include "sw/device/silicon_creator/lib/drivers/pinmux.h"
#include "sw/device/silicon_creator/lib/drivers/usb.h"
#include "sw/device/silicon_creator/lib/error.h"
#include "sw/device/silicon_creator/lib/rescue/rescue.h"
#include "sw/device/silicon_creator/lib/boot_data.h"
#include "sw/device/silicon_creator/lib/dbg_print.h"
#include "sw/device/silicon_creator/lib/drivers/rstmgr.h"

#include "hw/top_earlgrey/sw/autogen/top_earlgrey.h"


typedef struct dfu_usb {
  usb_control_ctx_t ep0;
  rescue_state_t state;
  boot_data_t *bootdata;
  uint8_t status[6];
  uint8_t dfu_state;
  uint8_t dfu_error;
  uint8_t interface;
} dfu_usb_t;

typedef struct rescue_mode_properties {
  uint32_t mode;
  bool dnload;
  bool upload;
} rescue_mode_properties_t;

static rescue_mode_properties_t mode_by_altsetting[] = {
  { kRescueModeFirmware, true, false },
  { kRescueModeFirmwareSlotB, true, false },
  { kRescueModeOpenTitanID, false, true },
  { kRescueModeBootLog, false, true },
  { kRescueModeBootSvcRsp, true, true },
  { kRescueModeOwnerPage0, true, true },
//  { kRescueModeOwnerPage1, false, true },
};

static const usb_device_descriptor_t device_desc = {
    .length = 18,
    .descriptor_type = 1,
    .bcd_usb = 0x0200,
    .device_class = 0,
    .device_sub_class = 0,
    .device_protocol = 0,
    .max_packet_size_0 = 64,
    .vendor = 0x18d1,
    .product = 0x503a,
    .bcd_device = 0x100,
    .imanufacturer = 1,
    .iproduct = 2,
    .iserial_number = 3,
    .num_configurations = 1,
};

#define DFU_INTERFACE_DSCR(alt) \
    USB_INTERFACE_DSCR( \
        /*inum=*/1, \
        /*alt=*/alt, \
        /*nep=*/0, \
        /*class=*/0xFE, \
        /*subclass=*/0x01, \
        /*protocol=*/2, \
        /*iint=*/4+alt)

static const uint8_t config_desc[] = {
    USB_CFG_DSCR_HEAD(
        /*total_len=*/USB_CFG_DSCR_LEN + 6 * USB_INTERFACE_DSCR_LEN + 9,
        /*nint=*/1),
    DFU_INTERFACE_DSCR(0),
    DFU_INTERFACE_DSCR(1),
    DFU_INTERFACE_DSCR(2),
    DFU_INTERFACE_DSCR(3),
    DFU_INTERFACE_DSCR(4),
    DFU_INTERFACE_DSCR(5),

    /* DFU Functional Descriptor */
    /*bLength=*/0x09,
    /*bDescriptorType=*/0x21,
    /*bmAttributes=*/0x07,  // will_detach=no, mftol=yes, upload=yes, dnload=yes
    /*wDetachTimeout*/ 0x00, 0x80,  // 32768ms
    /*wTransferSize*/ 0x00, 0x08,   // 2K
    /*bcdDFUVersion*/ 0x01, 0x01,   // 1.1
};

static const char lang_id[] = {
    /* bLength=*/4,
    /* bDescriptorType=*/3,
    /* bString=*/0x09,
    0x04,
};

static const char str_vendor[] = {
    USB_STRING_DSCR('G', 'o', 'o', 'g', 'l', 'e'),
};

static const char str_opentitan[] = {
    USB_STRING_DSCR('O', 'p', 'e', 'n', 'T', 'i', 't', 'a', 'n'),
};

static char str_serialnumber[2 + 32];

static const char str_resq[] = { USB_STRING_DSCR('R', 'e', 's', 'c', 'u', 'e') };
static const char str_resb[] = { USB_STRING_DSCR('R', 'e', 's', 'c', 'u', 'e', ' ', 'S', 'l', 'o', 't', 'B')};
static const char str_otid[] = { USB_STRING_DSCR('D','e','v','i','c','e','I','D') };
static const char str_blog[] = { USB_STRING_DSCR('B','o','o','t','L','o','g') };
static const char str_bsvc[] = { USB_STRING_DSCR('B','o','o','t','S','e','r','v','i','c','e','s') };
static const char str_ownr[] = { USB_STRING_DSCR('O','w','n','e','r','s','h','i','p') };


static const char *string_desc[] = {
    lang_id, str_vendor, str_opentitan, str_serialnumber,
str_resq,
str_resb,
str_otid,
str_blog,
str_bsvc,
str_ownr,
};

static void set_serialnumber(void) {
  lifecycle_device_id_t dev;
  lifecycle_device_id_get(&dev);
  const char hex[] = "0123456789ABCDEF";

  char *sn = str_serialnumber;
  *sn++ = 2 + 32;
  *sn++ = 3;
  for (size_t w = 1; w < 3; ++w) {
    uint8_t byte = (uint8_t)(dev.device_id[w] >> 24);
    *sn++ = hex[byte >> 4];
    *sn++ = 0;
    *sn++ = hex[byte & 15];
    *sn++ = 0;
    byte = (uint8_t)(dev.device_id[w] >> 16);
    *sn++ = hex[byte >> 4];
    *sn++ = 0;
    *sn++ = hex[byte & 15];
    *sn++ = 0;
    byte = (uint8_t)(dev.device_id[w] >> 8);
    *sn++ = hex[byte >> 4];
    *sn++ = 0;
    *sn++ = hex[byte & 15];
    *sn++ = 0;
    byte = (uint8_t)(dev.device_id[w] >> 0);
    *sn++ = hex[byte >> 4];
    *sn++ = 0;
    *sn++ = hex[byte & 15];
    *sn++ = 0;
  }
}

static void dfu_control(dfu_usb_t *ctx, usb_setup_data_t *setup) {
  if (setup->request <= kDfuReqAbort) {
    dfu_state_transition_t *tr = &dfu_state_table[setup->request][ctx->dfu_state];
    switch (tr->action) {
      case kDfuActionNone:
        ctx->dfu_state = tr->next[0];
        usb_ep_transfer(0, NULL, 0, kUsbTransferFlagsIn);
        break;
      case kDfuActionStall:
        ctx->dfu_state = tr->next[0];
        usb_ep_stall(0, true);
        break;
      case kDfuActionCheckLen:
        ctx->dfu_state = tr->next[setup->length == 0 ? 0 : 1];
        if (setup->length <= sizeof(ctx->state.data) &&
            (setup->request == kDfuReqDnLoad || setup->request == kDfuReqUpLoad)) {
            if (setup->request == kDfuReqDnLoad) {
              usb_ep_transfer(0, ctx->state.data, setup->length, setup->length == 0 ? kUsbTransferFlagsIn : kUsbTransferFlagsOut);
            } else {
              usb_transfer_flags_t flags = kUsbTransferFlagsIn;
              size_t length = MIN(ctx->state.staged_len, setup->length);
              if (length < setup->length && length % 64 == 0) flags |= kUsbTransferFlagsShortIn;
              usb_ep_transfer(0, ctx->state.data, length, flags);
            }
        } else {
          usb_ep_stall(0, true);
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
        usb_ep_transfer(0, ctx->status, sizeof(ctx->status),
                        kUsbTransferFlagsIn);
        break;
      case kDfuActionStateResponse:
        ctx->dfu_state = tr->next[0];
        usb_ep_transfer(0, &ctx->dfu_state, 1, kUsbTransferFlagsIn);
        break;
      case kDfuActionClearError:
        ctx->dfu_state = tr->next[0];
        ctx->dfu_error = kDfuErrOk;
        usb_ep_transfer(0, NULL, 0, kUsbTransferFlagsIn);
        break;
    }
  } else {
    ctx->dfu_state = kDfuStateError;
    ctx->dfu_error = kDfuErrUnknown;
    usb_ep_stall(0, true);
  }
}

static rom_error_t validate_mode(uint32_t setting, rescue_state_t *state,
                                 boot_data_t *bootdata) {
  if (setting >= ARRAYSIZE(mode_by_altsetting)) {
    return kErrorRescueBadMode;
  }
  rescue_mode_properties_t *mode = &mode_by_altsetting[setting];
  rom_error_t error2 = kErrorOk;
  rom_error_t error = rescue_validate_mode(mode->mode, state, bootdata);
  if (error ==kErrorOk && mode->upload) {
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

void dfu_handler(void *_ctx, size_t ep, usb_transfer_flags_t flags,
                 void *data) {
  dfu_usb_t *ctx = (dfu_usb_t *)_ctx;
  if (flags & kUsbTransferFlagsSetupData) {
    usb_setup_data_t *setup = (usb_setup_data_t *)data;

    if ((setup->request_type & kUsbReqTypeTypeMask) == kUsbReqTypeClass) {
      dfu_control(ctx, setup);
    } else if ((setup->request_type & kUsbReqTypeRecipientMask) == kUsbReqTypeInterface) {
      switch(setup->request) {
        case kUsbSetupReqSetInterface:
          if (validate_mode(setup->value, &ctx->state, ctx->bootdata) == kErrorOk) {
            ctx->interface = (uint8_t)setup->value;
            usb_ep_transfer(0, NULL, 0, kUsbTransferFlagsIn);
          } else {
            usb_ep_stall(0, true);
          }
          break;
        case kUsbSetupReqGetInterface:
          usb_ep_transfer(0, &ctx->interface, sizeof(ctx->interface), kUsbTransferFlagsIn);
          break;
        default:
          usb_ep_stall(0, true);
      }
    } else {
      usb_control_setupdata(&ctx->ep0, setup);
    }
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
      switch(error) {
        case kErrorOk:
          ctx->dfu_error = kDfuErrOk; break;
        default:
          ctx->dfu_error = kDfuErrVendor;
      }
      ctx->dfu_state= kDfuStateDnLoadIdle;
    } else if (ctx->dfu_state == kDfuStateUpLoadIdle) {
      if (length < 2048) {
        ctx->dfu_state = kDfuStateIdle;
      }
      ctx->state.staged_len = 0;
    }
  }

  if (flags & kUsbTransferFlagsReset) {
    dfu_state_transition_t *tr = &dfu_state_table[kDfuReqBusReset][ctx->dfu_state];
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

rom_error_t rescue_protocol(boot_data_t *bootdata,
                            const owner_rescue_config_t *config) {
  set_serialnumber();
  dfu_usb_t ctx = {
      .bootdata = bootdata,
      .ep0 =
          {
              .device_desc = &device_desc,
              .config_desc = config_desc,
              .string_desc = string_desc,
          },
      .dfu_state = kDfuStateIdle,
      .dfu_error = kDfuErrOk,
  };
  dbg_printf("USB-DFU rescue ready\r\n");
  rescue_state_init(&ctx.state, config);
  pinmux_init_usb();
  usb_init();
  usb_ep_init(0, kUsbEndpointTypeControl, 0x40, dfu_handler, &ctx);
  usb_enable(true);
  while (true) {
    usb_poll();
  }
  return kErrorOk;
}
