// Copyright 2026 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
#include "cryptoc/p384_ecdsa.h"
#include "cryptoc/p384.h"
#include "cryptoc/hmac.h"
#include "cryptoc/sha256.h"
#include <string.h>

// Compute k based on given {key, message} pair, 0 < k < n.
static void determine_k(const p384_int* key,
                        const p384_int* message,
                        char* tweak,
                        p384_int* k) {
  p384_int p;
  uint8_t buf[48];

  do {
    // Generate 48 bytes using HMAC-SHA-256 run twice with incremented tweak.
    LITE_HMAC_CTX hmac;
    uint8_t key_bin[48];
    uint8_t msg_bin[48];
    p384_to_bin(key, key_bin);
    p384_to_bin(message, msg_bin);

    // Block 1 (bytes 0-31)
    HMAC_SHA256_init(&hmac, key_bin, 48);
    HMAC_update(&hmac, tweak, 1);
    HMAC_update(&hmac, msg_bin, 48);
    ++(*tweak);
    memcpy(buf, HMAC_final(&hmac), 32);

    // Block 2 (bytes 32-47)
    HMAC_SHA256_init(&hmac, key_bin, 48);
    HMAC_update(&hmac, tweak, 1);
    HMAC_update(&hmac, msg_bin, 48);
    ++(*tweak);
    memcpy(buf + 32, HMAC_final(&hmac), 16);

    p384_from_bin(buf, &p);
  } while (p384_cmp(&p, &SECP384r1_nMin2) > 0);

  p384_add_d(&p, 1, k);
  p384_clear(&p);
}

void p384_ecdsa_sign(const p384_int* key,
                     const p384_int* message,
                     p384_int* r, p384_int* s) {
  char tweak = 'A';
  p384_digit top;

  for (;;) {
    p384_int k, kinv;

    determine_k(key, message, &tweak, &k);
    p384_base_point_mul(&k, r, s);
    p384_mod(&SECP384r1_n, r, r);

    // Make sure r != 0
    if (p384_is_zero(r)) continue;

    p384_modmul(&SECP384r1_n, r, 0, key, s);
    top = p384_add(s, message, s);
    p384_modinv(&SECP384r1_n, &k, &kinv);
    p384_modmul(&SECP384r1_n, &kinv, top, s, s);

    // Clear stack state
    p384_clear(&k);
    p384_clear(&kinv);

    // Make sure s != 0
    if (p384_is_zero(s)) continue;

    break;
  }
}

int p384_ecdsa_verify(const p384_int* key_x, const p384_int* key_y,
                      const p384_int* message,
                      const p384_int* r, const p384_int* s) {
  p384_int u, v;

  // Check public key.
  if (!p384_is_valid_point(key_x, key_y)) return 0;

  // Check r and s are != 0 % n.
  p384_mod(&SECP384r1_n, r, &u);
  p384_mod(&SECP384r1_n, s, &v);
  if (p384_is_zero(&u) || p384_is_zero(&v)) return 0;

  p384_modinv_vartime(&SECP384r1_n, s, &v);
  p384_modmul(&SECP384r1_n, message, 0, &v, &u);  // message / s % n
  p384_modmul(&SECP384r1_n, r, 0, &v, &v);  // r / s % n

  p384_points_mul_vartime(&u, &v,
                          key_x, key_y,
                          &u, &v);

  p384_mod(&SECP384r1_n, &u, &u);  // (x coord % p) % n
  return p384_cmp(r, &u) == 0;
}
