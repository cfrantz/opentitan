// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/silicon_creator/lib/ownership/ownership_activate.h"

#include "sw/device/lib/base/macros.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/silicon_creator/lib/boot_data.h"
#include "sw/device/silicon_creator/lib/boot_svc/boot_svc_msg.h"
#include "sw/device/silicon_creator/lib/drivers/hmac.h"
#include "sw/device/silicon_creator/lib/error.h"
#include "sw/device/silicon_creator/lib/ownership/ecdsa.h"
#include "sw/device/silicon_creator/lib/ownership/ownership.h"
#include "sw/device/silicon_creator/lib/ownership/ownership_key.h"

// These weak functions allow the unittest to replace them with mocks
// to simplify the testing.
OT_WEAK
hardened_bool_t activate_key_validate(size_t page, ownership_key_t key,
                                    const owner_signature_t *signature,
                                    const void *message, size_t len) {
  return ownership_key_validate(page, key, signature, message, len);
}

static rom_error_t activate(boot_svc_msg_t *msg, boot_data_t *bootdata) {
  size_t len = (uintptr_t)&msg->ownership_activate_req.signature -
               (uintptr_t)&msg->ownership_activate_req.primary_bl0_slot;
  if (activate_key_validate(/*page=*/1, kOwnershipKeyActivate,
                          &msg->ownership_activate_req.signature,
                          &msg->ownership_activate_req.primary_bl0_slot,
                          len) == kHardenedBoolFalse) {
    return kErrorOwnershipInvalidSignature;
  }
  if (ownership_page1_valid_for_transfer(bootdata) != kHardenedBoolTrue) {
    return kErrorOwnershipInvalidInfoPage;
  }

  // Seal page one to this chip.
  ownership_page_seal(/*page=*/1);

  // Program the sealed page into slot 1.
  HARDENED_RETURN_IF_ERROR(flash_ctrl_info_erase(&kFlashCtrlInfoPageOwnerSlot1,
                                                 kFlashCtrlEraseTypePage));
  HARDENED_RETURN_IF_ERROR(flash_ctrl_info_write(
      &kFlashCtrlInfoPageOwnerSlot1, 0, sizeof(owner_page[1]) / sizeof(uint32_t),
      &owner_page[1]));

  // Program the same data into slot 0.
  HARDENED_RETURN_IF_ERROR(flash_ctrl_info_erase(&kFlashCtrlInfoPageOwnerSlot0,
                                                 kFlashCtrlEraseTypePage));
  HARDENED_RETURN_IF_ERROR(flash_ctrl_info_write(
      &kFlashCtrlInfoPageOwnerSlot0, 0, sizeof(owner_page[1]) / sizeof(uint32_t),
      &owner_page[1]));
  bootdata->primary_bl0_slot = msg->ownership_activate_req.primary_bl0_slot;

  // Set the ownership state to LockedOwner.
  bootdata->ownership_state = kOwnershipStateLockedOwner;
  return kErrorWriteBootdataThenReboot;
}

rom_error_t ownership_activate_handler(boot_svc_msg_t *msg,
                                     boot_data_t *bootdata) {
  rom_error_t error = kErrorOwnershipInvalidRequest;
  switch (bootdata->ownership_state) {
    case kOwnershipStateLockedUpdate:
    case kOwnershipStateUnlockedAny:
    case kOwnershipStateUnlockedEndorsed:
      error = activate(msg, bootdata);
      break;
    default:
      /* nothing */;
  }
  boot_svc_ownership_activate_res_init(error, &msg->ownership_activate_res);
  return error;
}
