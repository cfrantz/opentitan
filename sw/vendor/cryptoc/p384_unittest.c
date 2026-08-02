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
#include <errno.h>
#include <stdlib.h>
#include <stdio.h>

#include "cryptoc/p384.h"

#define _TOSTR(x) #x
#define TOSTR(x) _TOSTR(x)
#define CHECK(x) \
    do { if (!(x)) { \
      errno = EADV; \
      perror(#x " @ line " TOSTR(__LINE__)); exit(1); }} while(0)

static int count_bits(const p384_int* a) {
  int i, n = 0;
  for (i = 0; i < 384; ++i) {
    n += p384_get_bit(a, i);
  }
  return n;
}

void test_cpu_behavior() {
  int32_t i;
  volatile int32_t val = -1;
  uint32_t one = 1;

  for (i = 0; i < 32; i++) {
    CHECK((val>>i) == (-1));
  }

  for (i = 0; i < 32; i++) {
    CHECK(0 != (((uint32_t)(val>>i)) & (one<<i)));
  }
}

void test_shifts() {
  p384_int a = {{1}};
  p384_int b;
  int i;

  for (i = 0; i < 383; ++i) {
    CHECK(p384_get_bit(&a, i) == 1);
    CHECK(!p384_is_zero(&a));
    CHECK(p384_shl(&a, 1, &a) == 0);
    CHECK(p384_get_bit(&a, i) == 0);
    CHECK(count_bits(&a) == 1);
  }
  CHECK(p384_get_bit(&a, i) == 1);
  CHECK(!p384_is_zero(&a));

  CHECK(p384_shl(&a, 1, &b) == 1);
  CHECK(p384_get_bit(&b, i) == 0);
  CHECK(p384_is_zero(&b));

  for (; i > 0; --i) {
    CHECK(p384_get_bit(&a, i) == 1);
    CHECK(!p384_is_zero(&a));
    p384_shr(&a, 1, &a);
    CHECK(p384_get_bit(&a, i) == 0);
    CHECK(count_bits(&a) == 1);
  }

  CHECK(p384_get_bit(&a, i) == 1);
  CHECK(!p384_is_zero(&a));

  p384_shr(&a, 1, &a);
  CHECK(p384_is_zero(&a));
}

void test_add_sub_cmp() {
  p384_int a = {{1}};
  p384_int b;
  p384_int one = {{1}};
  int i;

  for (i = 0; i < 383; ++i) {
    CHECK(count_bits(&a) == 1);
    CHECK(p384_sub(&a, &one, &b) == 0);
    CHECK(p384_cmp(&a, &b) == 1);
    CHECK(p384_cmp(&b, &a) == -1);
    CHECK(count_bits(&b) == i);
    CHECK(p384_add(&b, &one, &b) == 0);
    CHECK(count_bits(&b) == 1);
    CHECK(p384_cmp(&b, &a) == 0);

    CHECK(p384_shl(&a, 1, &a) == 0);
  }

  CHECK(p384_add(&a, &a, &b) == 1);  // expect carry
  CHECK(p384_is_zero(&b));
  CHECK(p384_cmp(&b, &a) == -1);
  CHECK(p384_sub(&b, &one, &b) == -1);  // expect borrow
  CHECK(p384_cmp(&b, &a) == 1);
}

void test_mul_inv() {
  p384_int a = {{1}};
  p384_int one = {{1}};
  p384_int b, c;
  int i;

  for (i = 0; i < 383; ++i) {
    p384_modinv(&SECP384r1_n, &a, &b);  // b = 1/a
    p384_modmul(&SECP384r1_n, &a, 0, &b, &c);  // c = b * a = 1
    CHECK(p384_cmp(&c, &one) == 0);

    p384_modinv_vartime(&SECP384r1_n, &b, &c);  // c = 1/b = a
    CHECK(p384_cmp(&a, &c) == 0);

    CHECK(p384_shl(&a, 1, &a) == 0);
  }
}

void test_valid_point() {
  extern const p384_int SECP384r1_Gx;
  extern const p384_int SECP384r1_Gy;
  CHECK(p384_is_valid_point(&SECP384r1_Gx, &SECP384r1_Gy) == 1);
}

int main(int argc, char* argv[]) {
  test_cpu_behavior();
  test_shifts();
  test_add_sub_cmp();
  test_mul_inv();
  test_valid_point();
  return 0;
}
