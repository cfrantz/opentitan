// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "sw/device/lib/arch/device.h"
#include "sw/device/lib/base/macros.h"
#include "sw/device/silicon_creator/lib/boot_data.h"
#include "sw/device/silicon_creator/lib/dbg_print.h"
#include "sw/device/silicon_creator/lib/drivers/rstmgr.h"
#include "sw/device/silicon_creator/lib/drivers/lifecycle.h"
#include "sw/device/silicon_creator/lib/drivers/usb.h"
#include "sw/device/silicon_creator/lib/drivers/spi_device.h"
#include "sw/device/silicon_creator/lib/error.h"
#include "sw/device/silicon_creator/lib/rescue/dfu.h"
#include "sw/device/silicon_creator/lib/rescue/rescue.h"

#include "hw/top_earlgrey/sw/autogen/top_earlgrey.h"


enum {
  /**
   * Base address of the spi_device registers.
   */
  kBase = TOP_EARLGREY_SPI_DEVICE_BASE_ADDR,
  /**
   * The flash buffer is a 2K region within the egress buffer, starting at the
   * beginning of the egress buffer.
   */
  kFlashBuffer = 0,
  /**
   * The mailbox buffer is a 1K region within the egress buffer starting at 2K
   */
  kMailboxBuffer = 2048,
  kMailboxAddress = 0x00FFF000,
};

extern const spi_device_sfdp_table_t kRescueSfdpTable;
extern const size_t kRescueSfdpTableSize;

extern uint32_t spi_device_control(void);

void dfu_transport_data(dfu_ctx_t *ctx, void *data, size_t len,
                        usb_transfer_flags_t flags) {
  if ((flags & kUsbTransferFlagsDirMask) == kUsbTransferFlagsIn) {
    spi_device_copy_to_egress(kFlashBuffer, data, len);
  } else {
    ctx->expected_len = len;
    // We do nothing for direction out because that is handled elsewhere.
  }
}

rom_error_t dfu_transport_setupdata(usb_control_ctx_t *ctx,
                                    usb_setup_data_t *setup) {
  // We don't handle the standard setupdata requests over SPI.
  return kErrorUsbBadSetup;
}

void dfu_transport_result(uint32_t result) {
  spi_device_copy_to_egress(kMailboxBuffer, &result, sizeof(result));
  spi_device_flash_status_clear();
}

rom_error_t rescue_protocol(boot_data_t *bootdata,
                            const owner_rescue_config_t *config) {
  dfu_ctx_t ctx = {
      .bootdata = bootdata,
      .dfu_state = kDfuStateIdle,
      .dfu_error = kDfuErrOk,
  };
  dbg_printf("SPI-DFU rescue ready\r\n");
  rescue_state_init(&ctx.state, config);
  spi_device_init(
      /*log2_density=*/24,
      &kRescueSfdpTable,
      kRescueSfdpTableSize);
  spi_device_enable_mailbox(kMailboxAddress);
  dbg_printf("control = %x\r\n", spi_device_control());

  spi_device_cmd_t cmd;
  uint32_t length;
  while (true) {
    rom_error_t result = spi_device_cmd_get(&cmd);
    if (result != kErrorOk) {
      break;
    }
    dbg_printf("SPI Got %x %x %x\r\n", cmd.opcode, cmd.address, cmd.payload_byte_count);
    switch(cmd.opcode) {
      case kSpiDeviceOpcodePageProgram: {
        if (cmd.address == kMailboxAddress) {
          usb_setup_data_t *setup = (usb_setup_data_t*)cmd.payload;
          dbg_hexdump(setup, sizeof(*setup));
          dfu_protocol_handler(&ctx, 0, kUsbTransferFlagsSetupData, setup);
        } else {
          uint32_t offset = cmd.address & 2047;
          memcpy(ctx.state.data+offset, cmd.payload, cmd.payload_byte_count);
          length = offset+cmd.payload_byte_count;
          if (length >= ctx.expected_len) {
            dfu_protocol_handler(&ctx, 0, kUsbTransferFlagsDone|kUsbTransferFlagsOut, &length);
            ctx.expected_len = 0;
          }
          spi_device_flash_status_clear();
        }
      }
      break;

      case kSpiDeviceOpcodeReset:
        rstmgr_reset();
        break;
      default:
        dfu_transport_result(kErrorUsbBadSetup);
    }
  }
  return kErrorOk;
}
