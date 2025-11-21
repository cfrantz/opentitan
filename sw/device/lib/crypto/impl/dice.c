// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/crypto/include/dice.h"

#include "sw/device/lib/base/macros.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/crypto/drivers/keymgr.h"
#include "sw/device/lib/crypto/drivers/otbn.h"
#include "sw/device/lib/crypto/impl/integrity.h"
#include "sw/device/lib/crypto/impl/status.h"
#include "sw/device/silicon_creator/lib/dbg_print.h"

// static_assert(kAttestationSeedWords <= 16, "Additional attestation seed needs
// must be <= 516 bits.");

OTBN_DECLARE_APP_SYMBOLS(boot);        // The OTBN boot-services app.
OTBN_DECLARE_SYMBOL_ADDR(boot, mode);  // Application mode.
OTBN_DECLARE_SYMBOL_ADDR(boot, msg);   // ECDSA message digest.
OTBN_DECLARE_SYMBOL_ADDR(boot, x);     // ECDSA public key x-coordinate.
OTBN_DECLARE_SYMBOL_ADDR(boot, y);     // ECDSA public key y-coordinate.
OTBN_DECLARE_SYMBOL_ADDR(boot, r);     // ECDSA signature component r.
OTBN_DECLARE_SYMBOL_ADDR(boot, s);     // ECDSA signature component s.
OTBN_DECLARE_SYMBOL_ADDR(boot, x_r);   // ECDSA verification result.
OTBN_DECLARE_SYMBOL_ADDR(boot, ok);    // ECDSA verification status.
OTBN_DECLARE_SYMBOL_ADDR(
    boot, attestation_additional_seed);  // Additional seed for ECDSA keygen.

static const otbn_app_t kOtbnAppBoot = OTBN_APP_T_INIT(boot);
static const otbn_addr_t kOtbnVarBootMode = OTBN_ADDR_T_INIT(boot, mode);
static const otbn_addr_t kOtbnVarBootMsg = OTBN_ADDR_T_INIT(boot, msg);
static const otbn_addr_t kOtbnVarBootX = OTBN_ADDR_T_INIT(boot, x);
static const otbn_addr_t kOtbnVarBootY = OTBN_ADDR_T_INIT(boot, y);
static const otbn_addr_t kOtbnVarBootR = OTBN_ADDR_T_INIT(boot, r);
static const otbn_addr_t kOtbnVarBootS = OTBN_ADDR_T_INIT(boot, s);
static const otbn_addr_t kOtbnVarBootXr = OTBN_ADDR_T_INIT(boot, x_r);
static const otbn_addr_t kOtbnVarBootOk = OTBN_ADDR_T_INIT(boot, ok);
static const otbn_addr_t kOtbnVarBootAttestationAdditionalSeed =
    OTBN_ADDR_T_INIT(boot, attestation_additional_seed);

enum {
  /*
   * Mode is represented by a single word.
   */
  kOtbnBootModeWords = 1,
  /*
   * Mode to run signature verification.
   *
   * Value taken from `boot.s`.
   */
  kOtbnBootModeSigverify = 0x7d3,
  /*
   * Mode to generate an attestation keypair.
   *
   * Value taken from `boot.s`.
   */
  kOtbnBootModeAttestationKeygen = 0x2bf,
  /*
   * Mode to endorse a message with a saved private key.
   *
   * Value taken from `boot.s`.
   */
  kOtbnBootModeAttestationEndorse = 0x5e8,
  /*
   * Mode to save an attesation private key.
   *
   * Value taken from `boot.s`.
   */
  kOtbnBootModeAttestationKeySave = 0x64d,
  kEcdsaP256PubWords = 8,
};

status_t dice_p256_keygen(otcrypto_blinded_key_t *private_key,
                          otcrypto_unblinded_key_t *public_key) {
  if (private_key == NULL || private_key->keyblob == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }
  // Check the key mode.
  if (private_key->config.key_mode != kOtcryptoKeyModeEcdsaP256) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(launder32(private_key->config.key_mode),
                    kOtcryptoKeyModeEcdsaP256);
  // Check the security config of the device.
  // HARDENED_TRY(security_config_check(private_key->config.security_level));

  HARDENED_TRY(otbn_load_app(kOtbnAppBoot));

  uint32_t mode = kOtbnBootModeAttestationKeygen;
  dice_diversifier_t *dd = (dice_diversifier_t *)private_key->keyblob;
  HARDENED_TRY(keymgr_generate_key_otbn_ex(
      *(keymgr_diversification_t *)&dd->diversifier, true));
  HARDENED_TRY(otbn_dmem_write(kOtbnBootModeWords, &mode, kOtbnVarBootMode));
  HARDENED_TRY(otbn_dmem_write(ARRAYSIZE(dd->attestation_seed),
                               dd->attestation_seed,
                               kOtbnVarBootAttestationAdditionalSeed));
  HARDENED_TRY(otbn_execute());
  HARDENED_TRY(otbn_busy_wait_for_done());
  if (public_key && public_key->key) {
    HARDENED_TRY(
        otbn_dmem_read(kEcdsaP256PubWords, kOtbnVarBootX, public_key->key));
    HARDENED_TRY(otbn_dmem_read(kEcdsaP256PubWords, kOtbnVarBootY,
                                public_key->key + kEcdsaP256PubWords));
  }
  public_key->checksum = integrity_unblinded_checksum(public_key);
  return OTCRYPTO_OK;
}

static status_t generate_private_key(
    const otcrypto_blinded_key_t *private_key) {
  if (private_key == NULL || private_key->keyblob == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }
  // Check the key mode.
  if (private_key->config.key_mode != kOtcryptoKeyModeEcdsaP256) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(launder32(private_key->config.key_mode),
                    kOtcryptoKeyModeEcdsaP256);
  // Check the security config of the device.
  // HARDENED_TRY(security_config_check(private_key->config.security_level));

  HARDENED_TRY(otbn_load_app(kOtbnAppBoot));

  uint32_t mode = kOtbnBootModeAttestationKeySave;
  dice_diversifier_t *dd = (dice_diversifier_t *)private_key->keyblob;
  HARDENED_TRY(keymgr_generate_key_otbn_ex(
      *(keymgr_diversification_t *)&dd->diversifier, true));
  HARDENED_TRY(otbn_dmem_write(kOtbnBootModeWords, &mode, kOtbnVarBootMode));
  HARDENED_TRY(otbn_dmem_write(ARRAYSIZE(dd->attestation_seed),
                               dd->attestation_seed,
                               kOtbnVarBootAttestationAdditionalSeed));
  HARDENED_TRY(otbn_execute());
  HARDENED_TRY(otbn_busy_wait_for_done());
  return OTCRYPTO_OK;
}

status_t dice_p256_sign(const otcrypto_blinded_key_t *private_key,
                        const otcrypto_hash_digest_t message_digest,
                        otcrypto_word32_buf_t signature) {
  HARDENED_TRY(generate_private_key(private_key));

  // Write the mode.
  uint32_t mode = kOtbnBootModeAttestationEndorse;
  HARDENED_TRY(otbn_dmem_write(kOtbnBootModeWords, &mode, kOtbnVarBootMode));

  // Write the message digest.
  // The boot services program processes the hash in reversed order.  Since we
  // accept the hash in normal order, we reverse while sending it to OTBN.
  for (size_t i = 0; i < 8; ++i) {
    uint32_t word = __builtin_bswap32(message_digest.data[7 - i]);
    otbn_dmem_write(1, &word, kOtbnVarBootMsg + (i * 4));
  }

  // Execute the signing operation.
  HARDENED_TRY(otbn_execute());
  HARDENED_TRY(otbn_busy_wait_for_done());

  // Retrieve the signature (in two parts, r and s).
  HARDENED_TRY(
      otbn_dmem_read(kEcdsaP256PubWords, kOtbnVarBootR, signature.data));
  HARDENED_TRY(otbn_dmem_read(kEcdsaP256PubWords, kOtbnVarBootS,
                              signature.data + kEcdsaP256PubWords));

  // Clear the key.
  HARDENED_TRY(otbn_dmem_sec_wipe());
  return OTCRYPTO_OK;
}

status_t dice_p256_verify(const otcrypto_unblinded_key_t *public_key,
                          const otcrypto_hash_digest_t message_digest,
                          const otcrypto_word32_buf_t signature,
                          uint32_t *recovered_r) {
  if (public_key == NULL || public_key->key == NULL) {
    return OTCRYPTO_BAD_ARGS;
  }
  // Check the key mode.
  if (public_key->key_mode != kOtcryptoKeyModeEcdsaP256) {
    return OTCRYPTO_BAD_ARGS;
  }
  HARDENED_CHECK_EQ(launder32(public_key->key_mode), kOtcryptoKeyModeEcdsaP256);
  HARDENED_TRY(otbn_load_app(kOtbnAppBoot));

  // Write the mode.
  uint32_t mode = kOtbnBootModeSigverify;
  HARDENED_TRY(otbn_dmem_write(kOtbnBootModeWords, &mode, kOtbnVarBootMode));

  // Write the public key.
  HARDENED_TRY(
      otbn_dmem_write(kEcdsaP256PubWords, public_key->key, kOtbnVarBootX));
  HARDENED_TRY(
      otbn_dmem_write(kEcdsaP256PubWords, public_key->key + 8, kOtbnVarBootY));

  // Write the message digest.
  // The boot services program processes the hash in reversed order.  Since we
  // accept the hash in normal order, we reverse while sending it to OTBN.
  for (size_t i = 0; i < 8; ++i) {
    uint32_t word = __builtin_bswap32(message_digest.data[7 - i]);
    otbn_dmem_write(1, &word, kOtbnVarBootMsg + (i * 4));
  }

  // Write the signature.
  HARDENED_TRY(
      otbn_dmem_write(kEcdsaP256PubWords, signature.data, kOtbnVarBootR));
  HARDENED_TRY(
      otbn_dmem_write(kEcdsaP256PubWords, signature.data + 8, kOtbnVarBootS));

  // Execute
  HARDENED_TRY(otbn_execute());
  HARDENED_TRY(otbn_busy_wait_for_done());

  hardened_bool_t result = 0;
  HARDENED_TRY(otbn_dmem_read(1, kOtbnVarBootOk, &result));
  if (result == kHardenedBoolTrue) {
    HARDENED_TRY(
        otbn_dmem_read(kEcdsaP256PubWords, kOtbnVarBootXr, recovered_r));
    return OTCRYPTO_OK;
  } else {
    memset(recovered_r, 0, 32);
    return OTCRYPTO_RECOV_ERR;
  }
}
