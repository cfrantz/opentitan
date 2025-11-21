// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_DICE_H_
#define OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_DICE_H_

#include <stddef.h>
#include <stdint.h>

#include "datatypes.h"

#ifdef __cplusplus
extern "C" {
#endif  // __cplusplus

/**
 * The DICE diversifier contains two diversification constants.
 *
 * - The diversifier is the keymgr 8-word + version diversification constant.
 * - The attestation_seed is additional per-chip fixed entropy that is normally
 *   stored in the AttestationKeySeeds flash INFO page (bank=0, page=4).  These
 *   constants are 320 bits (10 words) long.  Because OTBN's bignum registers
 *   are 256 bits wide, we program a full 512 bits to OTBN.  When you load the
 *   attestation seed, load 10 words from flash and set the remaining words to
 *   zero.
 */
typedef struct dice_keymgr_diversifier {
  uint32_t salt[8];
  uint32_t version;
} dice_keymgr_diversifier_t;

typedef struct dice_diversifier {
  dice_keymgr_diversifier_t diversifier;
  uint32_t attestation_seed[512 / 32];
} dice_diversifier_t;

/**
 * Generate an ECDSA P256 key from the DICE attestation keymgr.
 *
 * @param private_key A blinded key with a keyblob of `dice_diversifier_t`.
 * @param public_key[out] An unblinded key with a `key` pointer to a 64-byte
 *        buffer to receive the P256 x/y coordinates.
 * @return OTCRYPTO_OK.
 */
otcrypto_status_t dice_p256_keygen(otcrypto_blinded_key_t *private_key,
                                   otcrypto_unblinded_key_t *public_key);

/**
 * Sign a message with an ECDSA P256 key from the DICE attestation keymgr.
 *
 * @param private_key A blinded key with a keyblob of `dice_diversifier_t`.
 * @param message_digest A SHA256 hash of the message to sign.
 * @param signature[out] The resulting signature.
 * @return OTCRYPTO_OK.
 */
otcrypto_status_t dice_p256_sign(const otcrypto_blinded_key_t *private_key,
                                 const otcrypto_hash_digest_t message_digest,
                                 otcrypto_word32_buf_t signature);

/**
 * Verify a message with an ECDSA P256 key from the DICE attestation keymgr.
 *
 * Note: this is here as a debugging aide.  You should really use
 * `otcrypto_p256_verify` to verify signatures.  If you use this function,
 * you must check recovered_r to know if the signature was valid.
 *
 * @param private_key A blinded key with a keyblob of `dice_diversifier_t`.
 * @param message_digest The SHA256 hash of the message.
 * @param signature The signature to verify.
 * @param recovered_r The recovered R portion of the signature.
 * @return OTCRYPTO_OK.
 */
otcrypto_status_t dice_p256_verify(const otcrypto_unblinded_key_t *public_key,
                                   const otcrypto_hash_digest_t message_digest,
                                   const otcrypto_word32_buf_t signature,
                                   uint32_t *recovered_r);

#ifdef __cplusplus
}  // extern "C"
#endif  // __cplusplus

#endif  // OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_DICE_H_
