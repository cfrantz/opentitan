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
#ifndef SECURITY_UTIL_LITE_P384_H_
#define SECURITY_UTIL_LITE_P384_H_

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define P384_BITSPERDIGIT 32
#define P384_NDIGITS 12
#define P384_NBYTES 48

typedef int p384_err;
typedef uint32_t p384_digit;
typedef int32_t p384_sdigit;
typedef uint64_t p384_ddigit;
typedef int64_t p384_sddigit;

typedef struct
#ifdef SUPPORT_UNALIGNED
               __attribute__((packed))
#endif
{
  p384_digit a[P384_NDIGITS];
} p384_int;

extern const p384_int SECP384r1_n;      // Curve order
extern const p384_int SECP384r1_nMin2;  // Curve order - 2
extern const p384_int SECP384r1_p;      // Curve prime
extern const p384_int SECP384r1_b;      // Curve param b

void p384_init(p384_int* a);
void p384_clear(p384_int* a);

int p384_get_bit(const p384_int* a, int index);

void p384_mod(
    const p384_int* MOD,
    const p384_int* a,
    p384_int* b);

void p384_modmul(
    const p384_int* MOD,
    const p384_int* a,
    const p384_digit top_b,
    const p384_int* b,
    p384_int* c);

void p384_modinv(
    const p384_int* MOD,
    const p384_int* a,
    p384_int* b);

void p384_modinv_vartime(
    const p384_int* MOD,
    const p384_int* a,
    p384_int* b);

p384_digit p384_shl(const p384_int* a, int n, p384_int* b);
void p384_shr(const p384_int* a, int n, p384_int* b);

int p384_is_zero(const p384_int* a);
int p384_is_odd(const p384_int* a);
int p384_is_even(const p384_int* a);

int p384_cmp(const p384_int* a, const p384_int *b);

int p384_sub(const p384_int* a, const p384_int* b, p384_int* c);
int p384_add(const p384_int* a, const p384_int* b, p384_int* c);
int p384_add_d(const p384_int* a, p384_digit b, p384_int* c);

// EC point operations:
void p384_base_point_mul(const p384_int *n,
                         p384_int *out_x,
                         p384_int *out_y);

void p384_point_mul(const p384_int *n,
                    const p384_int *in_x,
                    const p384_int *in_y,
                    p384_int *out_x,
                    p384_int *out_y);

void p384_points_mul_vartime(
    const p384_int *n1, const p384_int *n2,
    const p384_int *in_x, const p384_int *in_y,
    p384_int *out_x, p384_int *out_y);

int p384_is_valid_point(const p384_int* x, const p384_int* y);

void p384_to_bin(const p384_int* src, uint8_t dst[P384_NBYTES]);
void p384_from_bin(const uint8_t src[P384_NBYTES], p384_int* dst);

#define P384_DIGITS(x) ((x)->a)
#define P384_DIGIT(x,y) ((x)->a[y])

#define P384_ZERO {{0}}
#define P384_ONE {{1}}

#ifdef __cplusplus
}
#endif

#endif  // SECURITY_UTIL_LITE_P384_H_
