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
#include <stdint.h>
#include <string.h>

#include "cryptoc/p384.h"

const p384_int SECP384r1_n =  // curve order
  {{0xccc52973, 0xecec196a, 0x48b0a77a, 0x581a0db2, 0xf4372ddf, 0xc7634d81,
    0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff}};

const p384_int SECP384r1_nMin2 =  // curve order - 2
  {{0xccc52973 - 2, 0xecec196a, 0x48b0a77a, 0x581a0db2, 0xf4372ddf, 0xc7634d81,
    0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff}};

const p384_int SECP384r1_p =  // curve field size
  {{0xffffffff, 0x00000000, 0x00000000, 0xffffffff, 0xfffffffe, 0xffffffff,
    0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff}};

const p384_int SECP384r1_b =  // curve b
  {{0xd3ec2aef, 0x2a85c8ed, 0x8a2ed19d, 0xc656398d, 0x5013875a, 0x0314088f,
    0xfe814112, 0x181d9c6e, 0xe3f82d19, 0x988e056b, 0xe23ee7e4, 0xb3312fa7}};

static const p384_int p384_one = P384_ONE;

void p384_init(p384_int* a) {
  memset(a, 0, sizeof(*a));
}

void p384_clear(p384_int* a) { p384_init(a); }

int p384_get_bit(const p384_int* scalar, int bit) {
  return (P384_DIGIT(scalar, bit / P384_BITSPERDIGIT)
              >> (bit & (P384_BITSPERDIGIT - 1))) & 1;
}

int p384_is_zero(const p384_int* a) {
  int i, result = 0;
  for (i = 0; i < P384_NDIGITS; ++i) result |= P384_DIGIT(a, i);
  return !result;
}

// top, c[] += a[] * b
// Returns new top
static p384_digit mulAdd(const p384_int* a,
                         p384_digit b,
                         p384_digit top,
                         p384_digit* c) {
  int i;
  p384_ddigit carry = 0;

  for (i = 0; i < P384_NDIGITS; ++i) {
    carry += *c;
    carry += (p384_ddigit)P384_DIGIT(a, i) * b;
    *c++ = (p384_digit)carry;
    carry >>= P384_BITSPERDIGIT;
  }
  return top + (p384_digit)carry;
}

// top, c[] -= top_a, a[]
static p384_digit subTop(p384_digit top_a,
                         const p384_digit* a,
                         p384_digit top_c,
                         p384_digit* c) {
  int i;
  p384_sddigit borrow = 0;

  for (i = 0; i < P384_NDIGITS; ++i) {
    borrow += *c;
    borrow -= *a++;
    *c++ = (p384_digit)borrow;
    borrow >>= P384_BITSPERDIGIT;
  }
  borrow += top_c;
  borrow -= top_a;
  top_c = (p384_digit)borrow;
  assert((borrow >> P384_BITSPERDIGIT) == 0);
  return top_c;
}

// top, c[] -= MOD[] & mask (0 or -1)
// returns new top.
static p384_digit subM(const p384_int* MOD,
                       p384_digit top,
                       p384_digit* c,
                       p384_digit mask) {
  int i;
  p384_sddigit borrow = 0;
  for (i = 0; i < P384_NDIGITS; ++i) {
    borrow += *c;
    borrow -= P384_DIGIT(MOD, i) & mask;
    *c++ = (p384_digit)borrow;
    borrow >>= P384_BITSPERDIGIT;
  }
  return top + (p384_digit)borrow;
}

// top, c[] += MOD[] & mask (0 or -1)
// returns new top.
static p384_digit addM(const p384_int* MOD,
                       p384_digit top,
                       p384_digit* c,
                       p384_digit mask) {
  int i;
  p384_ddigit carry = 0;
  for (i = 0; i < P384_NDIGITS; ++i) {
    carry += *c;
    carry += P384_DIGIT(MOD, i) & mask;
    *c++ = (p384_digit)carry;
    carry >>= P384_BITSPERDIGIT;
  }
  return top + (p384_digit)carry;
}

// c = a * b mod MOD. c can be a and/or b.
void p384_modmul(const p384_int* MOD,
                 const p384_int* a,
                 const p384_digit top_b,
                 const p384_int* b,
                 p384_int* c) {
  p384_digit tmp[P384_NDIGITS * 2 + 1] = { 0 };
  p384_digit top = 0;
  int i;

  // Multiply/add into tmp.
  for (i = 0; i < P384_NDIGITS; ++i) {
    if (i) tmp[i + P384_NDIGITS - 1] = top;
    top = mulAdd(a, P384_DIGIT(b, i), 0, tmp + i);
  }

  // Multiply/add top digit
  tmp[i + P384_NDIGITS - 1] = top;
  top = mulAdd(a, top_b, 0, tmp + i);

  // Reduce tmp, digit by digit.
  for (; i >= 0; --i) {
    p384_digit reducer[P384_NDIGITS] = { 0 };
    p384_digit top_reducer;

    // top can be any value at this point.
    // Guestimate reducer as top * MOD, since msw of MOD is -1.
    top_reducer = mulAdd(MOD, top, 0, reducer);

    // Subtract reducer from top | tmp.
    top = subTop(top_reducer, reducer, top, tmp + i);

    // top is now either 0 or 1. Make it 0, fixed-timing.
    assert(top <= 1);

    top = subM(MOD, top, tmp + i, ~(top - 1));

    assert(top == 0);

    // We have now reduced the top digit off tmp. Fetch new top digit.
    top = tmp[i + P384_NDIGITS - 1];
  }

  // tmp might still be larger than MOD, yet same bit length.
  // Make sure it is less, fixed-timing.
  addM(MOD, 0, tmp, subM(MOD, 0, tmp, -1));

  memcpy(c, tmp, P384_NBYTES);
}

int p384_is_odd(const p384_int* a) { return P384_DIGIT(a, 0) & 1; }
int p384_is_even(const p384_int* a) { return !(P384_DIGIT(a, 0) & 1); }

p384_digit p384_shl(const p384_int* a, int n, p384_int* b) {
  int i;
  p384_digit top = P384_DIGIT(a, P384_NDIGITS - 1);

  n %= P384_BITSPERDIGIT;
  for (i = P384_NDIGITS - 1; i > 0; --i) {
    p384_digit accu = (P384_DIGIT(a, i) << n);
    accu |= (P384_DIGIT(a, i - 1) >> (P384_BITSPERDIGIT - n));
    P384_DIGIT(b, i) = accu;
  }
  P384_DIGIT(b, i) = (P384_DIGIT(a, i) << n);

  top >>= (P384_BITSPERDIGIT - n);

  return top;
}

void p384_shr(const p384_int* a, int n, p384_int* b) {
  int i;

  n %= P384_BITSPERDIGIT;
  for (i = 0; i < P384_NDIGITS - 1; ++i) {
    p384_digit accu = (P384_DIGIT(a, i) >> n);
    accu |= (P384_DIGIT(a, i + 1) << (P384_BITSPERDIGIT - n));
    P384_DIGIT(b, i) = accu;
  }
  P384_DIGIT(b, i) = (P384_DIGIT(a, i) >> n);
}

static void p384_shr1(const p384_int* a, int highbit, p384_int* b) {
  int i;

  for (i = 0; i < P384_NDIGITS - 1; ++i) {
    p384_digit accu = (P384_DIGIT(a, i) >> 1);
    accu |= (P384_DIGIT(a, i + 1) << (P384_BITSPERDIGIT - 1));
    P384_DIGIT(b, i) = accu;
  }
  P384_DIGIT(b, i) = (P384_DIGIT(a, i) >> 1) |
      (highbit << (P384_BITSPERDIGIT - 1));
}

// Return -1, 0, 1 for a < b, a == b or a > b respectively.
int p384_cmp(const p384_int* a, const p384_int* b) {
  int i;
  p384_sddigit borrow = 0;
  p384_digit notzero = 0;

  for (i = 0; i < P384_NDIGITS; ++i) {
    borrow += (p384_sddigit)P384_DIGIT(a, i) - P384_DIGIT(b, i);
    notzero |= !!((p384_digit)borrow);
    borrow >>= P384_BITSPERDIGIT;
  }
  return (int)borrow | notzero;
}

// c = a - b. Returns borrow: 0 or -1.
int p384_sub(const p384_int* a, const p384_int* b, p384_int* c) {
  int i;
  p384_sddigit borrow = 0;

  for (i = 0; i < P384_NDIGITS; ++i) {
    borrow += (p384_sddigit)P384_DIGIT(a, i) - P384_DIGIT(b, i);
    if (c) P384_DIGIT(c, i) = (p384_digit)borrow;
    borrow >>= P384_BITSPERDIGIT;
  }
  return (int)borrow;
}

// c = a + b. Returns carry: 0 or 1.
int p384_add(const p384_int* a, const p384_int* b, p384_int* c) {
  int i;
  p384_ddigit carry = 0;

  for (i = 0; i < P384_NDIGITS; ++i) {
    carry += (p384_ddigit)P384_DIGIT(a, i) + P384_DIGIT(b, i);
    if (c) P384_DIGIT(c, i) = (p384_digit)carry;
    carry >>= P384_BITSPERDIGIT;
  }
  return (int)carry;
}

// b = a + d. Returns carry, 0 or 1.
int p384_add_d(const p384_int* a, p384_digit d, p384_int* b) {
  int i;
  p384_ddigit carry = d;

  for (i = 0; i < P384_NDIGITS; ++i) {
    carry += (p384_ddigit)P384_DIGIT(a, i);
    if (b) P384_DIGIT(b, i) = (p384_digit)carry;
    carry >>= P384_BITSPERDIGIT;
  }
  return (int)carry;
}

// if (mask) dst = src, fixed-timing style.
static void copyConditional(const p384_int* src,
                            p384_int* dst,
                            int mask) {
  int i;
  for (i = 0; i < P384_NDIGITS; ++i) {
    p384_digit b = P384_DIGIT(src, i) & mask;  // 0 or src[i]
    b |= P384_DIGIT(dst, i) & ~mask;  // dst[i] or 0
    P384_DIGIT(dst, i) = b;
  }
}

// -1 iff (x&15) == 0, 0 otherwise.
// Relies on arithmetic shift right behavior.
#define ZEROtoONES(x) (((int32_t)(((x)&15)-1))>>31)

// tbl[0] = tbl[idx], fixed-timing style.
static void set0ToIdx(p384_int tbl[16], int idx) {
  int32_t i;
  tbl[0] = p384_one;
  for (i = 1; i < 16; ++i) {
    copyConditional(&tbl[i], &tbl[0], ZEROtoONES(i-idx));
  }
}

// b = 1/a mod MOD, fixed timing, Fermat's little theorem.
void p384_modinv(const p384_int* MOD,
                 const p384_int* a,
                 p384_int* b) {
  p384_int tbl[16];
  int i;
  const p384_int* EXP = &SECP384r1_nMin2;

  if (p384_cmp(MOD, &SECP384r1_p) == 0) {
    static const p384_int SECP384r1_pMin2 =
      {{0xfffffffd, 0x00000000, 0x00000000, 0xffffffff, 0xfffffffe, 0xffffffff,
        0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff, 0xffffffff}};
    EXP = &SECP384r1_pMin2;
  }

  // tbl[i] = a**i, tbl[0] unused.
  tbl[1] = *a;
  for (i = 2; i < 16; ++i) {
    p384_modmul(MOD, &tbl[i-1], 0, a, &tbl[i]);
  }

  *b = p384_one;
  for (i = 384; i > 0; i -= 4) {
    int32_t idx = 0;
    p384_modmul(MOD, b, 0, b, b);
    p384_modmul(MOD, b, 0, b, b);
    p384_modmul(MOD, b, 0, b, b);
    p384_modmul(MOD, b, 0, b, b);
    idx |= p384_get_bit(EXP, i - 1) << 3;
    idx |= p384_get_bit(EXP, i - 2) << 2;
    idx |= p384_get_bit(EXP, i - 3) << 1;
    idx |= p384_get_bit(EXP, i - 4) << 0;
    set0ToIdx(tbl, idx);  // tbl[0] = tbl[idx]
    p384_modmul(MOD, b, 0, &tbl[0], &tbl[0]);
    copyConditional(&tbl[0], b, ~ZEROtoONES(idx));
  }
}

// b = 1/a mod MOD, binary euclid.
void p384_modinv_vartime(const p384_int* MOD,
                         const p384_int* a,
                         p384_int* b) {
  p384_int R = P384_ZERO;
  p384_int S = P384_ONE;
  p384_int U = *MOD;
  p384_int V = *a;

  for (;;) {
    if (p384_is_even(&U)) {
      p384_shr1(&U, 0, &U);
      if (p384_is_even(&R)) {
        p384_shr1(&R, 0, &R);
      } else {
        // R = (R+MOD)/2
        p384_shr1(&R, p384_add(&R, MOD, &R), &R);
      }
    } else if (p384_is_even(&V)) {
      p384_shr1(&V, 0, &V);
      if (p384_is_even(&S)) {
        p384_shr1(&S, 0, &S);
      } else {
        // S = (S+MOD)/2
        p384_shr1(&S, p384_add(&S, MOD, &S) , &S);
      }
    } else {  // U,V both odd.
      if (!p384_sub(&V, &U, NULL)) {
        p384_sub(&V, &U, &V);
        if (p384_sub(&S, &R, &S)) p384_add(&S, MOD, &S);
        if (p384_is_zero(&V)) break;  // done.
      } else {
        p384_sub(&U, &V, &U);
        if (p384_sub(&R, &S, &R)) p384_add(&R, MOD, &R);
      }
    }
  }

  p384_mod(MOD, &R, b);
}

void p384_mod(const p384_int* MOD,
              const p384_int* in,
              p384_int* out) {
  if (out != in) *out = *in;
  addM(MOD, 0, P384_DIGITS(out), subM(MOD, 0, P384_DIGITS(out), -1));
}

// Verify y^2 == x^3 - 3x + b mod p
// and 0 < x < p and 0 < y < p
int p384_is_valid_point(const p384_int* x, const p384_int* y) {
  p384_int y2, x3;

  if (p384_cmp(&SECP384r1_p, x) <= 0 ||
      p384_cmp(&SECP384r1_p, y) <= 0 ||
      p384_is_zero(x) ||
      p384_is_zero(y)) return 0;

  p384_modmul(&SECP384r1_p, y, 0, y, &y2);  // y^2

  p384_modmul(&SECP384r1_p, x, 0, x, &x3);  // x^2
  p384_modmul(&SECP384r1_p, x, 0, &x3, &x3);  // x^3
  if (p384_sub(&x3, x, &x3)) p384_add(&x3, &SECP384r1_p, &x3);  // x^3 - x
  if (p384_sub(&x3, x, &x3)) p384_add(&x3, &SECP384r1_p, &x3);  // x^3 - 2x
  if (p384_sub(&x3, x, &x3)) p384_add(&x3, &SECP384r1_p, &x3);  // x^3 - 3x
  if (p384_add(&x3, &SECP384r1_b, &x3))  // x^3 - 3x + b
    p384_sub(&x3, &SECP384r1_p, &x3);
  if (p384_sub(&x3, &SECP384r1_p, &x3))  // make sure 0 <= x3 < p
    p384_add(&x3, &SECP384r1_p, &x3);

  return p384_cmp(&y2, &x3) == 0;
}

void p384_from_bin(const uint8_t src[P384_NBYTES], p384_int* dst) {
  int i;
  const uint8_t* p = &src[0];

  for (i = P384_NDIGITS - 1; i >= 0; --i) {
    P384_DIGIT(dst, i) =
        (p[0] << 24) |
        (p[1] << 16) |
        (p[2] << 8) |
        p[3];
    p += 4;
  }
}

void p384_to_bin(const p384_int* src, uint8_t dst[P384_NBYTES]) {
  int i;
  uint8_t* p = &dst[0];

  for (i = P384_NDIGITS - 1; i >= 0; --i) {
    p384_digit digit = P384_DIGIT(src, i);
    p[0] = (uint8_t)(digit >> 24);
    p[1] = (uint8_t)(digit >> 16);
    p[2] = (uint8_t)(digit >> 8);
    p[3] = (uint8_t)(digit);
    p += 4;
  }
}
