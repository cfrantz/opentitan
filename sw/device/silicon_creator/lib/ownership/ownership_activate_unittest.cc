// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/silicon_creator/lib/ownership/ownership_activate.h"

#include <stdint.h>

#include "gmock/gmock.h"
#include "gtest/gtest.h"
#include "sw/device/lib/base/global_mock.h"
#include "sw/device/lib/base/hardened.h"
#include "sw/device/silicon_creator/lib/boot_data.h"
#include "sw/device/silicon_creator/lib/boot_svc/mock_boot_svc_header.h"
#include "sw/device/silicon_creator/lib/drivers/mock_flash_ctrl.h"
#include "sw/device/silicon_creator/lib/drivers/mock_hmac.h"
#include "sw/device/silicon_creator/lib/drivers/mock_rnd.h"
#include "sw/device/silicon_creator/lib/error.h"
#include "sw/device/silicon_creator/lib/nonce.h"
#include "sw/device/silicon_creator/lib/ownership/datatypes.h"
#include "sw/device/silicon_creator/lib/ownership/mock_ownership_key.h"
#include "sw/device/silicon_creator/lib/ownership/ownership.h"
#include "sw/device/silicon_creator/testing/rom_test.h"

namespace {
using ::testing::_;
using ::testing::Return;
using ::testing::SetArgPointee;

constexpr nonce_t kDefaultNonce = {1, 2};

class OwnershipActivateTest : public rom_test::RomTest {
 protected:
  boot_data_t bootdata_ = {
      .nonce = kDefaultNonce,
      .ownership_state = kOwnershipStateLockedOwner,
  };
  boot_svc_msg_t message_ = {
      .ownership_activate_req =
          {
              .header =
                  {
                      .type = kBootSvcOwnershipActivateReqType,
                  },
              .nonce = kDefaultNonce,
          },
  };

  rom_test::MockHmac hmac_;
  rom_test::MockRnd rnd_;
  rom_test::MockFlashCtrl flash_ctrl_;
  rom_test::MockBootSvcHeader hdr_;
  rom_test::MockOwnershipKey ownership_key_;
};

class OwnershipActivateInvalidStateTest
    : public OwnershipActivateTest,
      public testing::WithParamInterface<ownership_state_t> {};

class OwnershipActivateValidStateTest
    : public OwnershipActivateTest,
      public testing::WithParamInterface<ownership_state_t> {};

// Tests that requesting Activate in all Locked non-Update states fails.
TEST_P(OwnershipActivateInvalidStateTest, InvalidState) {
  bootdata_.ownership_state = static_cast<uint32_t>(GetParam());
  EXPECT_CALL(hdr_, Finalize(_, _, _));

  rom_error_t error = ownership_activate_handler(&message_, &bootdata_);
  EXPECT_EQ(error, kErrorOwnershipInvalidState);
}

INSTANTIATE_TEST_SUITE_P(AllCases, OwnershipActivateInvalidStateTest,
                         testing::Values(kOwnershipStateLockedOwner,
                                         kOwnershipStateLockedNone));

// Tests that an owner block with an invalid signature fails.
TEST_P(OwnershipActivateValidStateTest, InvalidSignature) {
  bootdata_.ownership_state = static_cast<uint32_t>(GetParam());
  EXPECT_CALL(ownership_key_, validate(1, kOwnershipKeyActivate, _, _, _))
      .WillOnce(Return(kHardenedBoolFalse));
  EXPECT_CALL(hdr_, Finalize(_, _, _));

  rom_error_t error = ownership_activate_handler(&message_, &bootdata_);
  EXPECT_EQ(error, kErrorOwnershipInvalidSignature);
}

// Tests that an owner block with an invalid nonce fails.
TEST_P(OwnershipActivateValidStateTest, InvalidNonce) {
  bootdata_.ownership_state = static_cast<uint32_t>(GetParam());
  bootdata_.nonce = {3, 4};
  EXPECT_CALL(ownership_key_, validate(1, kOwnershipKeyActivate, _, _, _))
      .WillOnce(Return(kHardenedBoolTrue));
  EXPECT_CALL(hdr_, Finalize(_, _, _));

  rom_error_t error = ownership_activate_handler(&message_, &bootdata_);
  EXPECT_EQ(error, kErrorOwnershipInvalidNonce);
}

// Tests that an owner block with an invalid owner page with respect to the
// current update state fails.
TEST_P(OwnershipActivateValidStateTest, OwnerPageInvalid) {
  ownership_state_t state = GetParam();
  if (state == kOwnershipStateUnlockedAny) {
    SUCCEED() << "There are no invalid conditions for UnlockedAny";
    return;
  }
  bootdata_.ownership_state = static_cast<uint32_t>(state);
  EXPECT_CALL(ownership_key_, validate(1, kOwnershipKeyActivate, _, _, _))
      .WillOnce(Return(kHardenedBoolTrue));

  rom_error_t expected_result = kErrorOk;
  owner_page_valid[1] = kOwnerPageStatusSigned;
  owner_page[0].owner_key = {{1}};
  bootdata_.next_owner[0] = UINT32_MAX;

  switch (state) {
    case kOwnershipStateLockedUpdate:
      // When the owner keys different between pages, validation must fail.
      owner_page[1].owner_key = {{2}};
      expected_result = kErrorOwnershipInvalidInfoPage;
      break;
    case kOwnershipStateUnlockedEndorsed:
      // When the hash of the owner key different from what is in bootdata,
      // validation must fail.
      EXPECT_CALL(hmac_, sha256(_, _, _))
          .WillOnce(SetArgPointee<2>((hmac_digest_t){{12345}}));
      expected_result = kErrorOwnershipInvalidInfoPage;
      break;
    default:
      FAIL() << "Invalid state for this test: " << state;
  }
  EXPECT_CALL(hdr_, Finalize(_, _, _));

  rom_error_t error = ownership_activate_handler(&message_, &bootdata_);
  EXPECT_EQ(error, expected_result);
}

// Tests that an owner block with a valid owner page with respect to the current
// update state succeeds.
TEST_P(OwnershipActivateValidStateTest, OwnerPageValid) {
  ownership_state_t state = GetParam();
  bootdata_.ownership_state = static_cast<uint32_t>(state);
  EXPECT_CALL(ownership_key_, validate(1, kOwnershipKeyActivate, _, _, _))
      .WillOnce(Return(kHardenedBoolTrue));

  owner_page_valid[1] = kOwnerPageStatusSigned;
  owner_page[0].owner_key = {{1}};
  memset(bootdata_.next_owner, 0, sizeof(bootdata_.next_owner));
  bootdata_.next_owner[0] = 12345;

  switch (state) {
    case kOwnershipStateLockedUpdate:
      // Validation passes when the owner keys are the same.
      owner_page[1].owner_key = {{1}};
      break;
    case kOwnershipStateUnlockedAny:
      // There are no validation conditions for UnlockedAny.
      break;
    case kOwnershipStateUnlockedEndorsed:
      // Validation passes when the new owner key hashes to the same
      // value in bootdata_.next_owner.
      EXPECT_CALL(hmac_, sha256(_, _, _))
          .WillOnce(SetArgPointee<2>((hmac_digest_t){{12345}}));
      break;
    default:
      FAIL() << "Invalid state for this test: " << state;
  }
  // Once the new owner page is determined to be valid, the page will be sealed.
  EXPECT_CALL(hmac_, sha256(_, _, _))
      .WillOnce(SetArgPointee<2>((hmac_digest_t){{0x5a5a5a5a}}));

  // The sealed page will be written into flash owner slot 1 first.
  EXPECT_CALL(flash_ctrl_,
              InfoErase(&kFlashCtrlInfoPageOwnerSlot1, kFlashCtrlEraseTypePage))
      .WillOnce(Return(kErrorOk));
  EXPECT_CALL(flash_ctrl_, InfoWrite(&kFlashCtrlInfoPageOwnerSlot1, 0,
                                     sizeof(owner_page[1]) / sizeof(uint32_t),
                                     &owner_page[1]))
      .WillOnce(Return(kErrorOk));
  // The sealed page will be written into flash owner slot 0 second.
  EXPECT_CALL(flash_ctrl_,
              InfoErase(&kFlashCtrlInfoPageOwnerSlot0, kFlashCtrlEraseTypePage))
      .WillOnce(Return(kErrorOk));
  EXPECT_CALL(flash_ctrl_, InfoWrite(&kFlashCtrlInfoPageOwnerSlot0, 0,
                                     sizeof(owner_page[1]) / sizeof(uint32_t),
                                     &owner_page[1]))
      .WillOnce(Return(kErrorOk));

  // The nonce will be regenerated.
  EXPECT_CALL(rnd_, Uint32()).WillRepeatedly(Return(99));
  // The boot_svc response will be finalized.
  EXPECT_CALL(hdr_, Finalize(_, _, _));

  rom_error_t error = ownership_activate_handler(&message_, &bootdata_);
  EXPECT_EQ(error, kErrorWriteBootdataThenReboot);
  // After succeeding, the page should be sealed, the nonce changed and the
  // ownership state set to LocedOwner.
  EXPECT_EQ(owner_page[1].seal[0], 0x5a5a5a5a);
  EXPECT_FALSE(nonce_equal(&bootdata_.nonce, &kDefaultNonce));
  EXPECT_EQ(bootdata_.ownership_state, kOwnershipStateLockedOwner);
}

INSTANTIATE_TEST_SUITE_P(AllCases, OwnershipActivateValidStateTest,
                         testing::Values(kOwnershipStateLockedUpdate,
                                         kOwnershipStateUnlockedAny,
                                         kOwnershipStateUnlockedEndorsed));

}  // namespace