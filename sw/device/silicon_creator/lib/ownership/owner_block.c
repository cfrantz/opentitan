// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/silicon_creator/lib/ownership/owner_block.h"

#include "sw/device/lib/base/macros.h"
#include "sw/device/silicon_creator/lib/boot_data.h"
#include "sw/device/silicon_creator/lib/drivers/flash_ctrl.h"
#include "sw/device/silicon_creator/lib/error.h"

#include "flash_ctrl_regs.h"

enum {
  kFlashBankSize = FLASH_CTRL_PARAM_REG_PAGES_PER_BANK,
};

rom_error_t owner_block_parse(const owner_block_t *block,
                              owner_config_t *config,
                              owner_application_keyring_t *keyring) {
  config->unknown_tags = 0;
  config->sram_exec = block->sram_exec_mode;
  config->flash = NULL;
  config->info = NULL;
  config->rescue = NULL;
  uint32_t remain = sizeof(block->data);
  uint32_t offset = 0;
  while (remain) {
    const tlv_header_t *item = (const tlv_header_t *)(block->data + offset);
    if (item->tag == 0 || item->length == 0) {
      break;
    }
    if (item->length > remain) {
      return kErrorOwnershipInvalidTagLength;
    }
    remain -= item->length;
    offset += item->length;
    switch (item->tag) {
      case kTlvTagApplicationKey:
        if (keyring->length < ARRAYSIZE(keyring->key)) {
          keyring->key[keyring->length++] =
              (const owner_application_key_t *)item;
        }
        break;
      case kTlvTagFlashConfig:
        if (config->flash)
          return kErrorOwnershipDuplicateItem;
        config->flash = (const owner_flash_config_t *)item;
        break;
      case kTlvTagInfoConfig:
        if (config->info)
          return kErrorOwnershipDuplicateItem;
        config->info = (const owner_flash_info_config_t *)item;
        break;
      case kTlvTagRescueConfig:
        if (config->rescue)
          return kErrorOwnershipDuplicateItem;
        config->rescue = (const owner_rescue_config_t *)item;
        break;
      default:
        /* unrecognized item. skip. */
        config->unknown_tags += 1;
    }
  }
  return kErrorOk;
}

#define MUBI(ex_) (ex_) ? kMultiBitBool4True : kMultiBitBool4False

rom_error_t owner_block_flash_apply(const owner_flash_config_t *flash,
                                    uint32_t config_side,
                                    uint32_t primary_side) {
  uint32_t start = config_side == kBootDataSlotA   ? 0
                   : config_side == kBootDataSlotB ? kFlashBankSize
                                                   : 0xFFFFFFFF;
  uint32_t end = config_side == kBootDataSlotA   ? kFlashBankSize
                 : config_side == kBootDataSlotB ? 2 * kFlashBankSize
                                                 : 0;
  size_t len = (flash->header.length - sizeof(owner_flash_config_t)) /
               sizeof(owner_flash_region_t);
  if (len >= 8) {
    return kErrorOwnershipFlashConfigLenth;
  }

  const owner_flash_region_t *config = flash->config;
  for (size_t i = 0; i < len; ++i, ++config) {
    if (config->start >= start && config->start + config->size <= end) {
      flash_ctrl_cfg_t cfg = {
          .scrambling = MUBI(config->properties & kOwnerFlashPropertyScramble),
          .ecc = MUBI(config->properties & kOwnerFlashPropertyEcc),
          .he = MUBI(config->properties & kOwnerFlashPropertyHighEndurance),
      };
      flash_ctrl_perms_t perm = {
          .read = MUBI(config->properties & kOwnerFlashPropertyRead),
          .write = MUBI(config->properties & kOwnerFlashPropertyProgram),
          .erase = MUBI(config->properties & kOwnerFlashPropertyErase),
      };
      if (config_side == primary_side &&
          config->properties & kOwnerFlashPropertyProtectWhenPrimary) {
        perm.write = kMultiBitBool4False;
        perm.erase = kMultiBitBool4False;
      }
      flash_ctrl_data_region_protect(i, config->start, config->size, perm, cfg);
    }
  }
  return kErrorOk;
}

static inline bool is_owner_page(const owner_info_page_t *config) {
  if (config->bank == 0) {
    if (config->page >= 6 && config->page <= 9) {
      // Currently, bank0, pages 6-9 (inclusive) are the pages reserved
      // for the owner's use.
      return true;
    }
  }
  return false;
}

rom_error_t owner_block_info_apply(const owner_flash_info_config_t *info) {
  size_t len = (info->header.length - sizeof(owner_flash_info_config_t)) /
               sizeof(owner_info_page_t);
  const owner_info_page_t *config = info->config;
  for (size_t i = 0; i < len; ++i, ++config) {
    if (is_owner_page(config)) {
      flash_ctrl_info_page_t page = {
          .base_addr = config->bank * FLASH_CTRL_PARAM_BYTES_PER_BANK +
                       config->page * FLASH_CTRL_PARAM_BYTES_PER_PAGE,
          .cfg_wen_addr =
              config->page * sizeof(uint32_t) +
              (config->bank == 0 ? FLASH_CTRL_BANK0_INFO0_REGWEN_0_REG_OFFSET
                                 : FLASH_CTRL_BANK1_INFO0_REGWEN_0_REG_OFFSET),
          .cfg_addr = config->page * sizeof(uint32_t) +
                      (config->bank == 0
                           ? FLASH_CTRL_BANK0_INFO0_PAGE_CFG_0_REG_OFFSET
                           : FLASH_CTRL_BANK1_INFO0_PAGE_CFG_0_REG_OFFSET),
      };
      flash_ctrl_cfg_t cfg = {
          .scrambling = MUBI(config->properties & kOwnerFlashPropertyScramble),
          .ecc = MUBI(config->properties & kOwnerFlashPropertyEcc),
          .he = MUBI(config->properties & kOwnerFlashPropertyHighEndurance),
      };
      flash_ctrl_info_cfg_set(&page, cfg);
      flash_ctrl_perms_t perm = {
          .read = MUBI(config->properties & kOwnerFlashPropertyRead),
          .write = MUBI(config->properties & kOwnerFlashPropertyProgram),
          .erase = MUBI(config->properties & kOwnerFlashPropertyErase),
      };
      flash_ctrl_info_perms_set(&page, perm);
    }
  }
  return kErrorOk;
}
