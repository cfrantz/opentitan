// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/silicon_creator/lib/ownership/ecdsa.h"

#include <stdbool.h>

#include "sw/device/lib/base/macros.h"
#ifdef USE_CRYPTOC
#include "sw/vendor/cryptoc/include/cryptoc/p256.h"
#include "sw/vendor/cryptoc/include/cryptoc/p256_ecdsa.h"
#include "sw/vendor/cryptoc/include/cryptoc/sha256.h"

// This satisfies cryptoc's use of the assert macro.
OT_WEAK void __assert_func(const char *file, int line, const char *func,
                           const char *expr) {
  while (true) {
    HARDENED_TRAP();
  }
}
#endif
#ifdef USE_OT_CRYPTOLIB
#include "sw/device/lib/crypto/include/ecc.h"
#include "sw/device/lib/crypto/include/hash.h"

static const otcrypto_ecc_curve_t kCurveP256 = {
    .curve_type = kOtcryptoEccCurveTypeNistP256,
    .domain_parameter = NULL,
};
#endif

hardened_bool_t ecdsa_verify_digest(const owner_key_t *pubkey,
                                    const owner_signature_t *signature,
                                    const owner_digest_t *digest) {
#ifdef USE_OT_CRYPTOLIB
  otcrypto_unblinded_key_t public_key = {
      .key_mode = kOtcryptoKeyModeEcdsa,
      .key_length = sizeof(pubkey->key),
      .key = (uint32_t *)pubkey->key,
  };
  otcrypto_hash_digest_t msg_digest = {
      .data = (uint32_t *)digest->digest,
      .len = ARRAYSIZE(digest->digest),
      .mode = kOtcryptoHashModeSha256,
  };

  hardened_bool_t result = kHardenedBoolFalse;
  status_t status =
      otcrypto_ecdsa_verify(&public_key, msg_digest,
                            (otcrypto_const_word32_buf_t){
                                .data = signature->signature,
                                .len = ARRAYSIZE(signature->signature),
                            },
                            &kCurveP256, &result);
  if (status.value != kOtcryptoStatusValueOk) {
    return kHardenedBoolFalse;
  }
#endif
#ifdef USE_CRYPTOC
  const p256_int *x = (const p256_int *)&pubkey->key[0];
  const p256_int *y = (const p256_int *)&pubkey->key[8];
  const p256_int *r = (const p256_int *)&signature->signature[0];
  const p256_int *s = (const p256_int *)&signature->signature[8];
  p256_int message;
  p256_from_bin((const uint8_t *)&digest->digest, &message);

  int ok = p256_ecdsa_verify(x, y, &message, r, s);
  hardened_bool_t result = ok ? kHardenedBoolTrue : kHardenedBoolFalse;
#endif
  return result;
}

hardened_bool_t ecdsa_sha256_digest(owner_digest_t *digest, const void *message,
                                    size_t message_len) {
#ifdef USE_OT_CRYPTOLIB
  otcrypto_const_byte_buf_t msg = {
      .len = message_len,
      .data = (unsigned char *)message,
  };
  otcrypto_hash_digest_t msg_digest = {
      .data = digest->digest,
      .len = ARRAYSIZE(digest->digest),
      .mode = kOtcryptoHashModeSha256,
  };
  status_t status = otcrypto_hash(msg, msg_digest);
  if (status.value != kOtcryptoStatusValueOk) {
    return kHardenedBoolFalse;
  }
#endif
#ifdef USE_CRYPTOC
  SHA256_hash(message, message_len, (uint8_t *)digest->digest);
#endif
  return kHardenedBoolTrue;
}

hardened_bool_t ecdsa_verify_message(const owner_key_t *pubkey,
                                     const owner_signature_t *signature,
                                     const void *message, size_t message_len) {
  owner_digest_t digest = {{0}};
  hardened_bool_t res = ecdsa_sha256_digest(&digest, message, message_len);
  if (res != kHardenedBoolTrue) {
    return kHardenedBoolFalse;
  }
  return ecdsa_verify_digest(pubkey, signature, &digest);
}
