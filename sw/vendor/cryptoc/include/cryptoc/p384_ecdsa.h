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
#ifndef SECURITY_UTIL_LITE_P384_ECDSA_H_
#define SECURITY_UTIL_LITE_P384_ECDSA_H_

#include "cryptoc/p384.h"

#ifdef __cplusplus
extern "C" {
#endif

// Signs a 384-bit message with a private key.
void p384_ecdsa_sign(const p384_int* key,
                     const p384_int* message,
                     p384_int* r, p384_int* s);

// Verifies a signature {r, s} on a 384-bit message with a public key.
// Returns 1 if valid, 0 otherwise.
int p384_ecdsa_verify(const p384_int* key_x,
                       const p384_int* key_y,
                       const p384_int* message,
                       const p384_int* r, const p384_int* s);

#ifdef __cplusplus
}
#endif

#endif  // SECURITY_UTIL_LITE_P384_ECDSA_H_
