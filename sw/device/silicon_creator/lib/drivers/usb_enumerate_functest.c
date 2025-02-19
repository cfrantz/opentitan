// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <stdbool.h>
#include <stdint.h>

#include "sw/device/lib/arch/device.h"
#include "sw/device/lib/runtime/print.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"
#include "sw/device/silicon_creator/lib/drivers/lifecycle.h"
#include "sw/device/silicon_creator/lib/drivers/pinmux.h"
#include "sw/device/silicon_creator/lib/drivers/usb.h"
#include "sw/device/silicon_creator/lib/error.h"

#include "hw/top_earlgrey/sw/autogen/top_earlgrey.h"

OTTF_DEFINE_TEST_CONFIG();

usb_device_descriptor_t device_desc = {
    .length = 18,
    .descriptor_type = 1,
    .bcd_usb = 0x0200,
    .device_class = 0xFF,
    .device_sub_class = 0xFF,
    .device_protocol = 0xFF,
    .max_packet_size_0 = 64,
    .vendor = 0x18d1,
    .product = 0x503a,
    .bcd_device = 0x100,
    .imanufacturer = 1,
    .iproduct = 2,
    .iserial_number = 3,
    .num_configurations = 1,
};

uint8_t config_desc[] = {
    USB_CFG_DSCR_HEAD(/*total_len=*/USB_CFG_DSCR_LEN, /*nint=*/0),
};

const char lang_id[] = {
    /* bLength=*/4,
    /* bDescriptorType=*/3,
    /* bString=*/0x09,
    0x04,
};

const char str_vendor[] = {
    USB_STRING_DSCR('G', 'o', 'o', 'g', 'l', 'e'),
};

const char str_opentitan[] = {
    USB_STRING_DSCR('O', 'p', 'e', 'n', 'T', 'i', 't', 'a', 'n'),
};

char str_serialnumber[2 + 32];

const char *string_desc[] = {
    lang_id, str_vendor, str_opentitan, str_serialnumber, NULL,
};

usb_control_ctx_t ep0 = {
    .device_desc = &device_desc,
    .config_desc = config_desc,
    .string_desc = string_desc,
};

void set_serialnumber(void) {
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

void handler(void *ctx, size_t ep, usb_transfer_flags_t flags, void *data) {
  if (flags & kUsbTransferFlagsSetupData) {
    usb_setup_data_t *setup = (usb_setup_data_t *)data;
    base_printf(
        "SETUPDATA: type=%02x req=%02x value=%04x index=%04x len=%04x\r\n",
        setup->request_type, setup->request, setup->value, setup->index,
        setup->length);
    rom_error_t error = usb_control_setupdata(&ep0, (usb_setup_data_t *)data);
    if (error != kErrorOk) {
      usb_ep_stall(0, true);
    }
  }
  if (flags & kUsbTransferFlagsDone) {
    if (ep0.flags & kUsbControlFlagsPendingAddress) {
      ep0.flags &= ~(unsigned)kUsbControlFlagsPendingAddress;
      ep0.device_address = ep0.next.device_address;
      usb_set_address(ep0.device_address);
      LOG_INFO("set_addr %u", ep0.device_address);
    }
    if (ep0.flags & kUsbControlFlagsPendingConfig) {
      ep0.flags &= ~(unsigned)kUsbControlFlagsPendingConfig;
      ep0.configuration = ep0.next.configuration;
      LOG_INFO("set_configuration %u", ep0.configuration);
    }
  }
}

rom_error_t usb_test(void) {
  set_serialnumber();
  usb_init();
  usb_ep_init(0, kUsbEndpointTypeControl, 0x40, handler, NULL);
  usb_enable(true);
  LOG_INFO("usb ready");
  while (!ep0.configuration) {
    usb_poll();
  }
  return kErrorOk;
}

bool test_main(void) {
  pinmux_init_usb();
  status_t result = OK_STATUS();
  EXECUTE_TEST(result, usb_test);
  return status_ok(result);
}
