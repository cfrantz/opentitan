// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/silicon_creator/rom_ext/rescue.h"

#include "sw/device/lib/base/memory.h"
#include "sw/device/silicon_creator/lib/drivers/pinmux.h"
#include "sw/device/silicon_creator/lib/dbg_print.h"
#include "sw/device/silicon_creator/lib/xmodem.h"
#include "sw/device/silicon_creator/lib/drivers/retention_sram.h"

typedef enum {
  /** `BLOG` */
  kRescueModeBootLog = 0x424c4f47,
  /** `BRSP` */
  kRescueModeBootSvcRsp = 0x42525350,
  /** `BREQ` */
  kRescueModeBootSvcReq = 0x42524551,
  /** `OWNR` */
  kRescueModeOwnerBlock = 0x4f574e52,
  /** `RSCU` */
  kRescueModeFirmware = 0x52534355,
  /** `REBO` */
  kRescueModeReboot = 0x5245424f,
  /** `DWIM` */
  kRescueModeDWIM = 0x4457494d,
} rescue_mode_t;

typedef struct RescueState {
  rescue_mode_t mode;
  uint32_t frame;
  uint32_t offset;
  uint32_t flash_offset;
  uint8_t data[2048];
} rescue_state_t;

static rescue_state_t rescue_state;

hardened_bool_t rescue_requested(void) {
  uint32_t res = kHardenedBoolTrue ^ SW_STRAP_RESCUE_VALUE;
  res ^= pinmux_read_straps();
  if (launder32(res) != kHardenedBoolTrue) {
    return kHardenedBoolFalse;
  }
  HARDENED_CHECK_EQ(res, kHardenedBoolTrue);
  return res;
}

static void validate_mode(uint32_t mode) {
  char *m = (char *)&mode;
  dbg_printf("\r\nmode: %C%C%C%C\r\n", m[3], m[2], m[1], m[0]);
  switch (mode) {
    case kRescueModeBootLog:
      dbg_printf("ok: receive boot_log via xmodem-crc\r\n");
      break;
    case kRescueModeBootSvcRsp:
      dbg_printf("ok: receive boot_svc response via xmodem-crc\r\n");
      break;
    case kRescueModeBootSvcReq:
      dbg_printf("ok: send boot_log request via xmodem-crc\r\n");
      break;
    case kRescueModeOwnerBlock:
      dbg_printf("ok: send owner_block via xmodem-crc\r\n");
      break;
    case kRescueModeFirmware:
      dbg_printf("ok: send firmware via xmodem-crc\r\n");
      break;
    case kRescueModeReboot:
      dbg_printf("ok: reboot\r\n");
      break;
    case kRescueModeDWIM:
      // Easter egg :)
      dbg_printf("error: i don't know what you mean\r\n");
      return;
    default:
      // User input error.  Do not change modes.
      dbg_printf("error: unrecognized mode\r\n");
      return;
  }
  rescue_state.mode = (rescue_mode_t)mode;
  rescue_state.frame = 1;
  rescue_state.offset = 0;
  rescue_state.flash_offset = 0;
}

static rom_error_t handle_send_modes(void) {
  const retention_sram_t *rr = retention_sram_get();
  switch (rescue_state.mode) {
    case kRescueModeBootLog:
      HARDENED_RETURN_IF_ERROR(
          xmodem_send(&rr->creator.boot_log, sizeof(rr->creator.boot_log)));
      break;
    case kRescueModeBootSvcRsp:
      HARDENED_RETURN_IF_ERROR(xmodem_send(&rr->creator.boot_svc_msg,
                                           sizeof(rr->creator.boot_svc_msg)));
      break;
    case kRescueModeBootSvcReq:
    case kRescueModeOwnerBlock:
    case kRescueModeFirmware:
      // Nothing to do for receive modes.
      return kErrorOk;
    case kRescueModeReboot:
      // If a reboot was requested, return an error and go through the normal
      // shutdown process.
      return kErrorRescueReboot;
    default:
      // This state should be impossible.
      return kErrorRescueBadMode;
  }
  validate_mode(kRescueModeFirmware);
  return kErrorOk;
}

static rom_error_t handle_recv_modes(void) {
  retention_sram_t *rr = retention_sram_get();
  switch (rescue_state.mode) {
    case kRescueModeBootLog:
    case kRescueModeBootSvcRsp:
      // Nothing to do for send modes.
      break;
    case kRescueModeBootSvcReq:
      if (rescue_state.offset >= sizeof(rr->creator.boot_svc_msg)) {
        memcpy(&rr->creator.boot_svc_msg, rescue_state.data,
               sizeof(rr->creator.boot_svc_msg));
        validate_mode(kRescueModeFirmware);
      }
      break;
    case kRescueModeOwnerBlock:
      if (rescue_state.offset == sizeof(rescue_state.data)) {
        dbg_printf("todo: owner_block\r\n");
        validate_mode(kRescueModeFirmware);
      }
      break;
    case kRescueModeFirmware:
      if (rescue_state.offset == sizeof(rescue_state.data)) {
        // TODO: handle flashing a firmware page if in range.
      }
      break;
    case kRescueModeReboot:
    default:
      // This state should be impossible.
      return kErrorRescueBadMode;
  }
  return kErrorOk;
}

rom_error_t rescue_protocol(void) {
  rom_error_t result;
  size_t rxlen;
  uint8_t command;
  uint32_t next_mode = 0;

  validate_mode(kRescueModeFirmware);
  xmodem_recv_start();
  while (true) {
    HARDENED_RETURN_IF_ERROR(handle_send_modes());
    result = xmodem_recv_frame(rescue_state.frame,
                               rescue_state.data + rescue_state.offset, &rxlen,
                               &command);
    if (rescue_state.frame == 1 && result == kErrorXModemTimeoutStart) {
      xmodem_recv_start();
      continue;
    }
    switch (result) {
      case kErrorOk:
        // Packet ok.
        rescue_state.offset += rxlen;
        HARDENED_RETURN_IF_ERROR(handle_recv_modes());
        xmodem_ack(true);
        break;
      case kErrorXModemEndOfFile:
        xmodem_ack(true);
        return kErrorOk;
      case kErrorXModemCrc:
        xmodem_ack(false);
        continue;
      case kErrorXModemCancel:
        return result;
      case kErrorXModemUnknown:
        if (rescue_state.frame == 1) {
            if (command == '\r') {
              validate_mode(next_mode);
              next_mode = 0;
            } else {
                next_mode = (next_mode << 8) | command;
            }
            continue;
        }
        OT_FALLTHROUGH_INTENDED;
      default:
        return result;
    }
    rescue_state.frame += 1;
  }
}
