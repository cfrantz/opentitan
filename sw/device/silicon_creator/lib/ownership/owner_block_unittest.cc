// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/silicon_creator/lib/ownership/owner_block.h"

#include <stdint.h>

#include "gmock/gmock.h"
#include "gtest/gtest.h"
#include "sw/device/lib/testing/binary_blob.h"
#include "sw/device/silicon_creator/lib/boot_data.h"
#include "sw/device/silicon_creator/lib/drivers/mock_flash_ctrl.h"
#include "sw/device/silicon_creator/lib/error.h"
#include "sw/device/silicon_creator/lib/ownership/datatypes.h"
#include "sw/device/silicon_creator/testing/rom_test.h"

namespace {
#include "sw/device/silicon_creator/lib/ownership/testdata/basic_owner.h"

using rom_test::FlashCfg;
using rom_test::FlashPerms;
using rom_test::MockFlashCtrl;
using ::testing::_;
using ::testutil::BinaryBlob;

class OwnerBlockTest : public rom_test::RomTest {
 protected:
  MockFlashCtrl flash_ctrl_;
};

const owner_flash_config_t simple_flash_config = {
    .header =
        {
            .tag = kTlvTagFlashConfig,
            .length =
                sizeof(owner_flash_config_t) + 6 * sizeof(owner_flash_region_t),
        },
    .config =
        {
            {
                // SideA ROM_EXT.
                .start = 0,
                .size = 32,
                .properties = kOwnerFlashPropertyRead |
                              kOwnerFlashPropertyProgram |
                              kOwnerFlashPropertyErase |
                              kOwnerFlashPropertyProtectWhenPrimary,
            },
            {
                // SideA FIRMWARE.
                .start = 32,
                .size = 192,
                .properties =
                    kOwnerFlashPropertyRead | kOwnerFlashPropertyProgram |
                    kOwnerFlashPropertyErase | kOwnerFlashPropertyScramble |
                    kOwnerFlashPropertyEcc |
                    kOwnerFlashPropertyProtectWhenPrimary,
            },
            {
                // SideA Filesystem.
                .start = 224,
                .size = 32,
                .properties =
                    kOwnerFlashPropertyRead | kOwnerFlashPropertyProgram |
                    kOwnerFlashPropertyErase | kOwnerFlashPropertyHighEndurance,
            },
            {
                // SideB ROM_EXT.
                .start = 256 + 0,
                .size = 32,
                .properties = kOwnerFlashPropertyRead |
                              kOwnerFlashPropertyProgram |
                              kOwnerFlashPropertyErase,
            },
            {
                // SideB FIRMWARE.
                .start = 256 + 32,
                .size = 192,
                .properties =
                    kOwnerFlashPropertyRead | kOwnerFlashPropertyProgram |
                    kOwnerFlashPropertyErase | kOwnerFlashPropertyScramble |
                    kOwnerFlashPropertyEcc,
            },
            {
                // SideB Filesystem.
                .start = 256 + 224,
                .size = 32,
                .properties =
                    kOwnerFlashPropertyRead | kOwnerFlashPropertyProgram |
                    kOwnerFlashPropertyErase | kOwnerFlashPropertyHighEndurance,
            },
        },
};

const owner_flash_config_t bad_flash_config = {
    .header =
        {
            .tag = kTlvTagFlashConfig,
            .length =
                sizeof(owner_flash_config_t) + 8 * sizeof(owner_flash_region_t),
        },
};

const owner_flash_info_config_t info_config = {
    .header =
        {
            .tag = kTlvTagInfoConfig,
            .length =
                sizeof(owner_flash_config_t) + 2 * sizeof(owner_flash_region_t),
        },
    .config =
        {
            {
                // User page
                .bank = 0,
                .page = 6,
                .properties =
                    kOwnerFlashPropertyRead | kOwnerFlashPropertyProgram |
                    kOwnerFlashPropertyErase | kOwnerFlashPropertyHighEndurance,
            },
            {
                // Disallowed page
                .bank = 0,
                .page = 5,
                .properties = kOwnerFlashPropertyRead |
                              kOwnerFlashPropertyProgram |
                              kOwnerFlashPropertyErase,
            },

        },
};

TEST_F(OwnerBlockTest, FlashConfigApplyBad) {
  rom_error_t error =
      owner_block_flash_apply(&bad_flash_config, kBootDataSlotA, 0);
  EXPECT_EQ(error, kErrorOwnershipFlashConfigLenth);
}

// Tests that the flash parameters get applied for side A.
TEST_F(OwnerBlockTest, FlashConfigApplySideA) {
  EXPECT_CALL(
      flash_ctrl_,
      DataRegionProtect(0, 0, 32,
                        FlashPerms(kMultiBitBool4True, kMultiBitBool4True,
                                   kMultiBitBool4True),
                        FlashCfg(kMultiBitBool4False, kMultiBitBool4False,
                                 kMultiBitBool4False)));
  EXPECT_CALL(
      flash_ctrl_,
      DataRegionProtect(1, 32, 192,
                        FlashPerms(kMultiBitBool4True, kMultiBitBool4True,
                                   kMultiBitBool4True),
                        FlashCfg(kMultiBitBool4True, kMultiBitBool4True,
                                 kMultiBitBool4False)));
  EXPECT_CALL(
      flash_ctrl_,
      DataRegionProtect(2, 224, 32,
                        FlashPerms(kMultiBitBool4True, kMultiBitBool4True,
                                   kMultiBitBool4True),
                        FlashCfg(kMultiBitBool4False, kMultiBitBool4False,
                                 kMultiBitBool4True)));

  rom_error_t error =
      owner_block_flash_apply(&simple_flash_config, kBootDataSlotA, 0);
  EXPECT_EQ(error, kErrorOk);
}

// Tests that the flash parameters get applied for side A and the
// ProtectWhenPrimary disables erase and program on the ROM_EXT and FIRMWARE
// regions.
TEST_F(OwnerBlockTest, FlashConfigApplySideAPrimary) {
  EXPECT_CALL(
      flash_ctrl_,
      DataRegionProtect(0, 0, 32,
                        FlashPerms(kMultiBitBool4True, kMultiBitBool4False,
                                   kMultiBitBool4False),
                        FlashCfg(kMultiBitBool4False, kMultiBitBool4False,
                                 kMultiBitBool4False)));
  EXPECT_CALL(
      flash_ctrl_,
      DataRegionProtect(1, 32, 192,
                        FlashPerms(kMultiBitBool4True, kMultiBitBool4False,
                                   kMultiBitBool4False),
                        FlashCfg(kMultiBitBool4True, kMultiBitBool4True,
                                 kMultiBitBool4False)));
  EXPECT_CALL(
      flash_ctrl_,
      DataRegionProtect(2, 224, 32,
                        FlashPerms(kMultiBitBool4True, kMultiBitBool4True,
                                   kMultiBitBool4True),
                        FlashCfg(kMultiBitBool4False, kMultiBitBool4False,
                                 kMultiBitBool4True)));

  rom_error_t error = owner_block_flash_apply(&simple_flash_config,
                                              kBootDataSlotA, kBootDataSlotA);
  EXPECT_EQ(error, kErrorOk);
}

// Tests that the flash parameters get applied for side B.
TEST_F(OwnerBlockTest, FlashConfigApplySideB) {
  EXPECT_CALL(
      flash_ctrl_,
      DataRegionProtect(3, 256 + 0, 32,
                        FlashPerms(kMultiBitBool4True, kMultiBitBool4True,
                                   kMultiBitBool4True),
                        FlashCfg(kMultiBitBool4False, kMultiBitBool4False,
                                 kMultiBitBool4False)));
  EXPECT_CALL(
      flash_ctrl_,
      DataRegionProtect(4, 256 + 32, 192,
                        FlashPerms(kMultiBitBool4True, kMultiBitBool4True,
                                   kMultiBitBool4True),
                        FlashCfg(kMultiBitBool4True, kMultiBitBool4True,
                                 kMultiBitBool4False)));
  EXPECT_CALL(
      flash_ctrl_,
      DataRegionProtect(5, 256 + 224, 32,
                        FlashPerms(kMultiBitBool4True, kMultiBitBool4True,
                                   kMultiBitBool4True),
                        FlashCfg(kMultiBitBool4False, kMultiBitBool4False,
                                 kMultiBitBool4True)));

  rom_error_t error =
      owner_block_flash_apply(&simple_flash_config, kBootDataSlotB, 0);
  EXPECT_EQ(error, kErrorOk);
}

TEST_F(OwnerBlockTest, FlashInfoApply) {
  EXPECT_CALL(flash_ctrl_,
              InfoCfgSet(_, FlashCfg(kMultiBitBool4False, kMultiBitBool4False,
                                     kMultiBitBool4True)));
  EXPECT_CALL(flash_ctrl_,
              InfoPermsSet(_, FlashPerms(kMultiBitBool4True, kMultiBitBool4True,
                                         kMultiBitBool4True)));

  rom_error_t error = owner_block_info_apply(&info_config);
  EXPECT_EQ(error, kErrorOk);
}

TEST_F(OwnerBlockTest, ParseBlock) {
  BinaryBlob<owner_block_t> block(basic_owner, sizeof(basic_owner));
  owner_config_t config;
  owner_application_keyring_t keyring{};

  rom_error_t error = owner_block_parse(block.get(), &config, &keyring);
  EXPECT_EQ(error, kErrorOk);
  EXPECT_EQ(config.unknown_tags, 0);
  EXPECT_EQ(config.sram_exec, kOwnerSramExecModeDisabledLocked);
  EXPECT_EQ(config.flash->header.tag, kTlvTagFlashConfig);
  EXPECT_EQ(config.info->header.tag, kTlvTagInfoConfig);
  EXPECT_EQ(config.rescue->header.tag, kTlvTagRescueConfig);
  EXPECT_EQ(keyring.length, 1);
  EXPECT_EQ(keyring.key[0]->header.tag, kTlvTagApplicationKey);
}

TEST_F(OwnerBlockTest, ParseBlockBadHeader) {
  BinaryBlob<owner_block_t> block(basic_owner, sizeof(basic_owner));
  // Rewrite the header length to a bad value
  block.Seek(sizeof(uint32_t)).Write(12345);
  owner_config_t config;
  owner_application_keyring_t keyring{};
  rom_error_t error = owner_block_parse(block.get(), &config, &keyring);
  EXPECT_EQ(error, kErrorOwnershipInvalidTagLength);

  // Rewrite the header tag from `OWNR` to `AAAA`.
  block.Reset().Write(0x41414141);
  error = owner_block_parse(block.get(), &config, &keyring);
  EXPECT_EQ(error, kErrorOwnershipInvalidTag);
}

TEST_F(OwnerBlockTest, ParseBlockUnknownTag) {
  BinaryBlob<owner_block_t> block(basic_owner, sizeof(basic_owner));
  // Write an unknown header of {tag="AAAA", len=0x40} after the RESQ config.
  uint32_t len =
      block.Find(kTlvTagRescueConfig).Seek(sizeof(uint32_t)).Read<uint32_t>() -
      sizeof(tlv_header_t);
  block.Seek(len).Write(0x41414141).Write(0x40);
  owner_config_t config;
  owner_application_keyring_t keyring{};
  rom_error_t error = owner_block_parse(block.get(), &config, &keyring);
  EXPECT_EQ(error, kErrorOk);
  EXPECT_EQ(config.unknown_tags, 1);
}

TEST_F(OwnerBlockTest, ParseBlockBadLength) {
  BinaryBlob<owner_block_t> block(basic_owner, sizeof(basic_owner));
  // Rewrite the RESQ block length to overflow the TLV region.
  block.Find(kTlvTagRescueConfig).Seek(sizeof(uint32_t)).Write(uint32_t(0x5f1));
  owner_config_t config;
  owner_application_keyring_t keyring{};
  rom_error_t error = owner_block_parse(block.get(), &config, &keyring);
  EXPECT_EQ(error, kErrorOwnershipInvalidTagLength);
}

TEST_F(OwnerBlockTest, ParseBlockDupFlash) {
  BinaryBlob<owner_block_t> block(basic_owner, sizeof(basic_owner));
  // Rewrite the RESQ tag as a FLSH tag to test duplicate detection.
  block.Find(kTlvTagRescueConfig).Write(kTlvTagFlashConfig);
  owner_config_t config;
  owner_application_keyring_t keyring{};
  rom_error_t error = owner_block_parse(block.get(), &config, &keyring);
  EXPECT_EQ(error, kErrorOwnershipDuplicateItem);
}

TEST_F(OwnerBlockTest, ParseBlockDupInfo) {
  BinaryBlob<owner_block_t> block(basic_owner, sizeof(basic_owner));
  // Rewrite the RESQ tag as an INFO tag to test duplicate detection.
  block.Find(kTlvTagRescueConfig).Write(kTlvTagInfoConfig);
  owner_config_t config;
  owner_application_keyring_t keyring{};
  rom_error_t error = owner_block_parse(block.get(), &config, &keyring);
  EXPECT_EQ(error, kErrorOwnershipDuplicateItem);
}

TEST_F(OwnerBlockTest, ParseBlockDupRescue) {
  BinaryBlob<owner_block_t> block(basic_owner, sizeof(basic_owner));
  // Rewrite the FLSH tag as a RESQ tag to test duplicate detection.
  block.Find(kTlvTagFlashConfig).Write(kTlvTagRescueConfig);
  owner_config_t config;
  owner_application_keyring_t keyring{};
  rom_error_t error = owner_block_parse(block.get(), &config, &keyring);
  EXPECT_EQ(error, kErrorOwnershipDuplicateItem);
}
}  // namespace
