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
#include <assert.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <ctype.h>

#include <openssl/ec.h>
#include <openssl/ecdsa.h>
#include <openssl/obj_mac.h>

#include "cryptoc/p384.h"
#include "cryptoc/p384_ecdsa.h"
#include "cryptoc/p256_prng.h"

// Turn p384 point into ossl compatible binary array.
static int to_oct(const p384_int* x, const p384_int* y, uint8_t* buf) {
  buf[0] = 4;
  p384_to_bin(x, buf + 1);
  p384_to_bin(y, buf + 1 + 48);
  return 97;
}

// Turn p384 r,s into ossl compatible signature array.
static int to_sig(const p384_int* r, const p384_int* s, uint8_t* buf) {
  uint8_t* p = buf;
  uint8_t tmp_r[48 + 1], tmp_s[48 + 1];
  int size_r = sizeof(tmp_r), size_s = sizeof(tmp_s);
  int i;

  tmp_r[0] = 0;
  p384_to_bin(r, tmp_r + 1);
  tmp_s[0] = 0;
  p384_to_bin(s, tmp_s + 1);

  for (i = 0; !tmp_r[i] && i < sizeof(tmp_r); ++i) --size_r;
  if (tmp_r[i] & 0x80) ++size_r;
  for (i = 0; !tmp_s[i] && i < sizeof(tmp_s); ++i) --size_s;
  if (tmp_s[i] & 0x80) ++size_s;

  *p++ = 0x30;  // sequence tag
  *p++ = 2 + size_r + 2 + size_s;

  *p++ = 0x02;  // int tag
  *p++ = size_r;
  memcpy(p, &tmp_r[sizeof(tmp_r) - size_r], size_r);
  p += size_r;

  *p++ = 0x02;  // int tag
  *p++ = size_s;
  memcpy(p, &tmp_s[sizeof(tmp_s) - size_s], size_s);
  p += size_s;

  return p - buf;
}

static int ossl_verify(const p384_int* Gx, const p384_int* Gy,
                       uint8_t* message,
                       const p384_int* r, const p384_int* s) {
  int result = 0;
  uint8_t pk[97];
  uint8_t sig[110];
  int siglen, pklen;

  EC_KEY* key = EC_KEY_new();
  EC_GROUP* group = EC_GROUP_new_by_curve_name(NID_secp384r1);
  EC_POINT* point = EC_POINT_new(group);

  EC_KEY_set_group(key, group);

  pklen = to_oct(Gx, Gy, pk);

  EC_POINT_oct2point(group, point, pk, pklen, 0);
  EC_KEY_set_public_key(key, point);

  siglen = to_sig(r, s, sig);

  result = (ECDSA_verify(0, message, 48, sig, siglen, key) == 1);

  EC_POINT_free(point);
  EC_GROUP_free(group);
  EC_KEY_free(key);

  return result;
}

static void draw48(P256_PRNG_CTX* prng, uint8_t dst[48]) {
  uint8_t tmp1[32];
  uint8_t tmp2[32];
  p256_prng_draw(prng, tmp1);
  p256_prng_draw(prng, tmp2);
  memcpy(dst, tmp1, 32);
  memcpy(dst + 32, tmp2, 16);
}

static void random_sigs_test() {
  int n;
  P256_PRNG_CTX prng;
  uint8_t tmp[48];
  uint32_t boot_count = time(NULL);

  p256_prng_init(&prng, "random_sigs_test_p384", 21, boot_count);

  for (n = 0; n < 100; ++n) {
    p384_int a, b, Gx, Gy;
    p384_int r, s;

    // Make up private key
    do {
      p384_int p1, p2;
      draw48(&prng, tmp);
      p384_from_bin(tmp, &p1);
      draw48(&prng, tmp);
      p384_from_bin(tmp, &p2);
      p384_modmul(&SECP384r1_n, &p1, 0, &p2, &a);
    } while (p384_is_zero(&a));

    // Compute public key; a is our secret key.
    p384_base_point_mul(&a, &Gx, &Gy);

    // Pick random message to sign.
    draw48(&prng, tmp);
    p384_from_bin(tmp, &b);

    // Compute signature on b.
    p384_ecdsa_sign(&a, &b, &r, &s);

    if (!p384_ecdsa_verify(&Gx, &Gy, &b, &r, &s)) {
      printf("p384_ecdsa_verify fail at %d! (boot_count %d)\n", n, boot_count);
      exit(1);
    }

    if (!ossl_verify(&Gx, &Gy, tmp, &r, &s)) {
      printf("ossl_verify p384 fail at %d! (boot_count %d)\n", n, boot_count);
      exit(1);
    }
  }
}

static void invalid_sigs_test() {
  P256_PRNG_CTX prng;
  uint8_t tmp[48];
  uint32_t boot_count = time(NULL);

  p256_prng_init(&prng, "invalid_sigs_test_p384", 22, boot_count);

  {
    p384_int a, b, Gx, Gy;
    p384_int r, s;

    // Make up private key
    do {
      p384_int p1, p2;
      draw48(&prng, tmp);
      p384_from_bin(tmp, &p1);
      draw48(&prng, tmp);
      p384_from_bin(tmp, &p2);
      p384_modmul(&SECP384r1_n, &p1, 0, &p2, &a);
    } while (p384_is_zero(&a));

    p384_base_point_mul(&a, &Gx, &Gy);

    draw48(&prng, tmp);
    p384_from_bin(tmp, &b);

    p384_ecdsa_sign(&a, &b, &r, &s);

    if (!p384_ecdsa_verify(&Gx, &Gy, &b, &r, &s)) {
      printf("invalid_sigs_test() verify fail!\n");
      exit(1);
    }

    // Modify r to be out of range / incorrect
    if (p384_ecdsa_verify(&Gx, &Gy, &b, &SECP384r1_n, &s)) {
      printf("invalid_sigs_test() verify should fail on incorrect signature!\n");
      exit(1);
    }
  }
}

static void hex_decode(const char* hex, uint8_t* bin) {
  while (*hex) {
    char h = *hex++;
    char l = *hex++;
    *bin++ = ((h >= 'a' ? h - 'a' + 10 : (h >= 'A' ? h - 'A' + 10 : h - '0')) << 4) |
             (l >= 'a' ? l - 'a' + 10 : (l >= 'A' ? l - 'A' + 10 : l - '0'));
  }
}

static void nist_cavp_test() {
  const char* qx_hex = "3BF701BC9E9D36B4D5F1455343F09126F2564390F2B487365071243C61E6471FB9D2AB74657B82F9086489D9EF0F5CB5";
  const char* qy_hex = "D1A358EAFBF952E68D533855CCBDAA6FF75B137A5101443199325583552A6295FFE5382D00CFCDA30344A9B5B68DB855";
  const char* r_hex = "30EA514FC0D38D8208756F068113C7CADA9F66A3B40EA3B313D040D9B57DD41A332795D02CC7D507FCEF9FAF01A27088";
  const char* s_hex = "CC808E504BE414F46C9027BCBF78ADF067A43922D6FCAA66C4476875FBB7B94EFD1F7D5DBE620BFB821C46D549683AD8";
  const char* msg_hex = "5AEA187D1C4F6E1B35057D20126D836C6ADBBC7049EE0299C9529F5E0B3F8B5A7411149D6C30D6CB2B8AF70E0A781E89";

  uint8_t bin[48];
  p384_int qx, qy, r, s, msg;

  hex_decode(qx_hex, bin); p384_from_bin(bin, &qx);
  hex_decode(qy_hex, bin); p384_from_bin(bin, &qy);
  hex_decode(r_hex, bin); p384_from_bin(bin, &r);
  hex_decode(s_hex, bin); p384_from_bin(bin, &s);
  hex_decode(msg_hex, bin); p384_from_bin(bin, &msg);

  if (!p384_ecdsa_verify(&qx, &qy, &msg, &r, &s)) {
    printf("nist_cavp_test(): verification failed!\n");
    exit(1);
  }
  printf("P-384 NIST CAVP test vector verified successfully.\n");
}

int main(int argc, char* argv[]) {
  nist_cavp_test();
  random_sigs_test();
  invalid_sigs_test();
  printf("All P-384 ECDSA tests passed.\n");
  return 0;
}
