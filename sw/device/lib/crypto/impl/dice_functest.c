// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/base/status.h"
#include "sw/device/lib/crypto/drivers/entropy.h"
#include "sw/device/lib/crypto/impl/ecc/p256.h"
#include "sw/device/lib/crypto/impl/status.h"
#include "sw/device/lib/crypto/include/datatypes.h"
#include "sw/device/lib/crypto/include/dice.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/entropy_testutils.h"
#include "sw/device/lib/testing/hexstr.h"
#include "sw/device/lib/testing/keymgr_testutils.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"
#include "sw/device/silicon_creator/lib/base/util.h"
#include "sw/device/silicon_creator/lib/dbg_print.h"

// Keymgr handle for this test.
static dif_keymgr_t keymgr;

OTTF_DEFINE_TEST_CONFIG();

// uint32_t random_order_random_word(void) { return 0xc0ffee11; }

status_t dice_test(void) {
  char buf[256];
  dice_diversifier_t dd = {
      .diversifier =
          {
              .salt = {0x00010203, 0x04050607, 0x08090a0b, 0x0c0d0e0f,
                       0xf0f1f2f3, 0xf4f5f6f7, 0xf8f9fafb, 0xfcfdfeff},
              .version = 0,
          },
      .attestation_seed = {0x70717273, 0x74757677, 0x78797a7b, 0x7c7d7e7f,
                           0x80818283, 0x84858687, 0x88898a8b, 0x8c8d8e8f,
                           0x90b1b2b3, 0x94959697},
  };
  otcrypto_blinded_key_t private_key = {
      .config =
          {
              .key_mode = kOtcryptoKeyModeEcdsaP256,
          },
      .keyblob = (uint32_t *)&dd,
  };

  uint32_t key_material[16] = {0};
  otcrypto_unblinded_key_t public_key = {
      .key_mode = kOtcryptoKeyModeEcdsaP256,
      .key = key_material,
  };

  TRY(dice_p256_keygen(&private_key, &public_key));
  hexstr_encode(buf, sizeof(buf), key_material, sizeof(key_material));
  dbg_printf("Public key: %s\r\n", buf);

  uint32_t sigdata[16] = {0};
  otcrypto_word32_buf_t signature = {
      .data = sigdata,
      .len = 16,
  };

  uint32_t digest_data[8] = {1, 2, 3, 4, 5, 6, 7, 8};
  otcrypto_hash_digest_t digest = {
      .mode = 0,
      .data = digest_data,
      .len = 8,
  };

  hexstr_encode(buf, sizeof(buf), digest_data, sizeof(digest_data));
  dbg_printf("Message: %s\r\n", buf);
  TRY(dice_p256_sign(&private_key, digest, signature));

  hexstr_encode(buf, sizeof(buf), sigdata, sizeof(sigdata));
  dbg_printf("Signature: %s\r\n", buf);

  hardened_bool_t result = 0;

  uint32_t rr[8];
  TRY(dice_p256_verify(&public_key, digest, signature, rr));
  hexstr_encode(buf, sizeof(buf), rr, sizeof(rr));
  dbg_printf("Debug recovered_r: %s\r\n", buf);
  CHECK_ARRAYS_EQ(rr, sigdata, ARRAYSIZE(rr));

  result = 0;
  TRY(p256_ecdsa_verify_start((const p256_ecdsa_signature_t *)sigdata,
                              digest_data, (const p256_point_t *)key_material));
  TRY(p256_ecdsa_verify_finalize((const p256_ecdsa_signature_t *)sigdata,
                                 &result));
  dbg_printf("Verify = %x\r\n", result);

  return OTCRYPTO_OK;
}

bool test_main(void) {
  //  Initialize the entropy complex, KMAC, and the key manager.
  CHECK_STATUS_OK(entropy_complex_init());
  dif_kmac_t kmac;
  CHECK_STATUS_OK(keymgr_testutils_startup(&keymgr, &kmac));
  CHECK_STATUS_OK(
      keymgr_testutils_check_state(&keymgr, kDifKeymgrStateCreatorRootKey));

  status_t result = OTCRYPTO_OK;

  EXECUTE_TEST(result, dice_test);
  return status_ok(result);
}
