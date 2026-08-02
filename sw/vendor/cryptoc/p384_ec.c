// Copyright 2026 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses///LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
#include <string.h>
#include "cryptoc/p384.h"

// SECP384r1 base point G coordinates
const p384_int SECP384r1_Gx =
  {{0x72760ab7, 0x3a545e38, 0xbf55296c, 0x5502f25d, 0x82542a38, 0x59f741e0,
    0x8ba79b98, 0x6e1d3b62, 0xf320ad74, 0x8eb1c71e, 0xbe8b0537, 0xaa87ca22}};

const p384_int SECP384r1_Gy =
  {{0x90ea0e5f, 0x7a431d7c, 0x1d7e819d, 0x0a60b1ce, 0xb5f0b8c0, 0xe9da3113,
    0x289a147c, 0xf8f41dbd, 0x9292dc29, 0x5d9e98bf, 0x96262c6f, 0x3617de4a}};

static const p384_int p384_one = P384_ONE;

typedef struct {
  p384_int X;
  p384_int Y;
  p384_int Z;
} jacobian_point;

static void p384_modadd(const p384_int* a, const p384_int* b, p384_int* c) {
  if (p384_add(a, b, c) || p384_cmp(c, &SECP384r1_p) >= 0) {
    p384_sub(c, &SECP384r1_p, c);
  }
}

static void p384_modsub(const p384_int* a, const p384_int* b, p384_int* c) {
  if (p384_sub(a, b, c)) {
    p384_add(c, &SECP384r1_p, c);
  }
}

// if (mask) dst = src, fixed-timing style.
static void copyConditional(p384_digit* dst, const p384_digit* src, int mask) {
  int i;
  for (i = 0; i < P384_NDIGITS; ++i) {
    p384_digit b = src[i] & mask;
    b |= dst[i] & ~mask;
    dst[i] = b;
  }
}

static void copy_conditional_point(const jacobian_point* src, jacobian_point* dst, int mask) {
  copyConditional(dst->X.a, src->X.a, mask);
  copyConditional(dst->Y.a, src->Y.a, mask);
  copyConditional(dst->Z.a, src->Z.a, mask);
}

static void jacobian_double(const jacobian_point* P, jacobian_point* R) {
  p384_int t1, t2, t3, t4, M, S, t5, t6, t7, t8, Y2, Z2;
  jacobian_point tmp_R;

  if (p384_is_zero(&P->Z)) {
    p384_init(&R->X);
    p384_init(&R->Y);
    p384_init(&R->Z);
    return;
  }

  // Y2 = Y^2
  p384_modmul(&SECP384r1_p, &P->Y, 0, &P->Y, &Y2);
  if (p384_is_zero(&Y2)) {
    p384_init(&R->X);
    p384_init(&R->Y);
    p384_init(&R->Z);
    return;
  }

  // Z2 = Z^2
  p384_modmul(&SECP384r1_p, &P->Z, 0, &P->Z, &Z2);

  // M = 3*(X - Z2)*(X + Z2)
  p384_modsub(&P->X, &Z2, &t1);
  p384_modadd(&P->X, &Z2, &t2);
  p384_modmul(&SECP384r1_p, &t1, 0, &t2, &t3);
  p384_modadd(&t3, &t3, &t4);
  p384_modadd(&t4, &t3, &M);

  // S = 4 * X * Y^2
  p384_modmul(&SECP384r1_p, &P->X, 0, &Y2, &t5);
  p384_modadd(&t5, &t5, &t6);
  p384_modadd(&t6, &t6, &S);

  // X' = M^2 - 2*S
  p384_modmul(&SECP384r1_p, &M, 0, &M, &t7);
  p384_modadd(&S, &S, &t8);
  p384_modsub(&t7, &t8, &tmp_R.X);

  // Y' = M * (S - X') - 8 * Y^4
  p384_modsub(&S, &tmp_R.X, &t1);
  p384_modmul(&SECP384r1_p, &M, 0, &t1, &t2);
  p384_modmul(&SECP384r1_p, &Y2, 0, &Y2, &t3); // Y^4
  p384_modadd(&t3, &t3, &t4);
  p384_modadd(&t4, &t4, &t4);
  p384_modadd(&t4, &t4, &t4); // t4 = 8 * Y^4
  p384_modsub(&t2, &t4, &tmp_R.Y);

  // Z' = 2 * Y * Z
  p384_modmul(&SECP384r1_p, &P->Y, 0, &P->Z, &t5);
  p384_modadd(&t5, &t5, &tmp_R.Z);

  *R = tmp_R;
}

static void jacobian_add(const jacobian_point* P, const jacobian_point* Q, jacobian_point* R) {
  p384_int Z1_2, Z2_2, Z1_3, Z2_3, U1, U2, S1, S2, H, r, H2, H3, U1_H2;
  p384_int t1, t2, t3;
  jacobian_point tmp_R;

  if (p384_is_zero(&P->Z)) {
    *R = *Q;
    return;
  }
  if (p384_is_zero(&Q->Z)) {
    *R = *P;
    return;
  }

  // Z1_2 = Z1^2, Z2_2 = Z2^2
  p384_modmul(&SECP384r1_p, &P->Z, 0, &P->Z, &Z1_2);
  p384_modmul(&SECP384r1_p, &Q->Z, 0, &Q->Z, &Z2_2);

  // Z1_3 = Z1^3 = Z1_2 * Z1, Z2_3 = Z2^3 = Z2_2 * Z2
  p384_modmul(&SECP384r1_p, &Z1_2, 0, &P->Z, &Z1_3);
  p384_modmul(&SECP384r1_p, &Z2_2, 0, &Q->Z, &Z2_3);

  // U1 = X1 * Z2_2, U2 = X2 * Z1_2
  p384_modmul(&SECP384r1_p, &P->X, 0, &Z2_2, &U1);
  p384_modmul(&SECP384r1_p, &Q->X, 0, &Z1_2, &U2);

  // S1 = Y1 * Z2_3, S2 = Y2 * Z1_3
  p384_modmul(&SECP384r1_p, &P->Y, 0, &Z2_3, &S1);
  p384_modmul(&SECP384r1_p, &Q->Y, 0, &Z1_3, &S2);

  if (p384_cmp(&U1, &U2) == 0) {
    if (p384_cmp(&S1, &S2) == 0) {
      jacobian_double(P, R);
    } else {
      p384_init(&R->X);
      p384_init(&R->Y);
      p384_init(&R->Z);
    }
    return;
  }

  // H = U2 - U1, r = S2 - S1
  p384_modsub(&U2, &U1, &H);
  p384_modsub(&S2, &S1, &r);

  // H2 = H^2, H3 = H^2 * H
  p384_modmul(&SECP384r1_p, &H, 0, &H, &H2);
  p384_modmul(&SECP384r1_p, &H2, 0, &H, &H3);

  // U1_H2 = U1 * H2
  p384_modmul(&SECP384r1_p, &U1, 0, &H2, &U1_H2);

  // X3 = r^2 - H3 - 2 * U1_H2
  p384_modmul(&SECP384r1_p, &r, 0, &r, &t1);
  p384_modsub(&t1, &H3, &t2);
  p384_modadd(&U1_H2, &U1_H2, &t3);
  p384_modsub(&t2, &t3, &tmp_R.X);

  // Y3 = r * (U1_H2 - X3) - S1 * H3
  p384_modsub(&U1_H2, &tmp_R.X, &t1);
  p384_modmul(&SECP384r1_p, &r, 0, &t1, &t2);
  p384_modmul(&SECP384r1_p, &S1, 0, &H3, &t3);
  p384_modsub(&t2, &t3, &tmp_R.Y);

  // Z3 = Z1 * Z2 * H
  p384_modmul(&SECP384r1_p, &P->Z, 0, &Q->Z, &t1);
  p384_modmul(&SECP384r1_p, &t1, 0, &H, &tmp_R.Z);

  *R = tmp_R;
}

static void jacobian_to_affine(const jacobian_point* P, p384_int* x, p384_int* y) {
  p384_int Zinv, Zinv2, Zinv3;
  if (p384_is_zero(&P->Z)) {
    p384_init(x);
    p384_init(y);
    return;
  }
  p384_modinv(&SECP384r1_p, &P->Z, &Zinv);
  p384_modmul(&SECP384r1_p, &Zinv, 0, &Zinv, &Zinv2);
  p384_modmul(&SECP384r1_p, &Zinv2, 0, &Zinv, &Zinv3);
  p384_modmul(&SECP384r1_p, &P->X, 0, &Zinv2, x);
  p384_modmul(&SECP384r1_p, &P->Y, 0, &Zinv3, y);
}

void p384_point_mul(const p384_int *n,
                    const p384_int *in_x,
                    const p384_int *in_y,
                    p384_int *out_x,
                    p384_int *out_y) {
  jacobian_point R, P;
  int i;

  P.X = *in_x;
  P.Y = *in_y;
  P.Z = p384_one;

  p384_init(&R.X);
  p384_init(&R.Y);
  p384_init(&R.Z); // Infinity

  for (i = 383; i >= 0; --i) {
    int bit = p384_get_bit(n, i);
    jacobian_point double_R, add_R;
    jacobian_double(&R, &double_R);
    jacobian_add(&double_R, &P, &add_R);

    int32_t mask = -bit;
    copy_conditional_point(&add_R, &double_R, mask);
    R = double_R;
  }

  jacobian_to_affine(&R, out_x, out_y);
}

void p384_base_point_mul(const p384_int *n,
                         p384_int *out_x,
                         p384_int *out_y) {
  p384_point_mul(n, &SECP384r1_Gx, &SECP384r1_Gy, out_x, out_y);
}

void p384_points_mul_vartime(
    const p384_int *n1, const p384_int *n2,
    const p384_int *in_x, const p384_int *in_y,
    p384_int *out_x, p384_int *out_y) {
  jacobian_point R, G_jac, P_jac;
  int i;

  G_jac.X = SECP384r1_Gx;
  G_jac.Y = SECP384r1_Gy;
  G_jac.Z = p384_one;

  P_jac.X = *in_x;
  P_jac.Y = *in_y;
  P_jac.Z = p384_one;

  p384_init(&R.X);
  p384_init(&R.Y);
  p384_init(&R.Z); // Infinity

  for (i = 383; i >= 0; --i) {
    jacobian_double(&R, &R);
    if (p384_get_bit(n1, i)) {
      jacobian_add(&R, &G_jac, &R);
    }
    if (p384_get_bit(n2, i)) {
      jacobian_add(&R, &P_jac, &R);
    }
  }

  jacobian_to_affine(&R, out_x, out_y);
}
