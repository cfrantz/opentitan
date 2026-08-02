// Force rebuild comment.
// Copyright 2016 Google Inc.
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
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "cryptoc/sha256.h"
#include "cryptoc/sha384.h"
#include "cryptoc/sha512.h"

static void hex_decode(const char* hex, uint8_t* out) {
  size_t len = strlen(hex);
  for (size_t i = 0; i < len; i += 2) {
    unsigned int val;
    sscanf(hex + i, "%2x", &val);
    out[i / 2] = (uint8_t)val;
  }
}

static int verify_sha256(const char* msg, const char* expected_hex) {
  uint8_t expected[32];
  uint8_t got[32];
  hex_decode(expected_hex, expected);

  SHA256_hash(msg, strlen(msg), got);

  if (memcmp(got, expected, 32) != 0) {
    printf("SHA-256 mismatch for message '%s'\n", msg);
    return 0;
  }
  return 1;
}

static int verify_sha384(const char* msg, const char* expected_hex) {
  uint8_t expected[48];
  uint8_t got[48];
  hex_decode(expected_hex, expected);

  SHA384_hash(msg, strlen(msg), got);

  if (memcmp(got, expected, 48) != 0) {
    printf("SHA-384 mismatch for message '%s'\n", msg);
    return 0;
  }
  return 1;
}

static int verify_sha512(const char* msg, const char* expected_hex) {
  uint8_t expected[64];
  uint8_t got[64];
  hex_decode(expected_hex, expected);

  SHA512_hash(msg, strlen(msg), got);

  if (memcmp(got, expected, 64) != 0) {
    printf("SHA-512 mismatch for message '%s'\n", msg);
    return 0;
  }
  return 1;
}

int main(int argc, char* argv[]) {
  int ok = 1;

  // SHA-256 Test Vectors
  ok &= verify_sha256("", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
  ok &= verify_sha256("abc", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
  ok &= verify_sha256("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
                      "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1");

  // SHA-384 Test Vectors
  ok &= verify_sha384("", "38b060a751ac96384cd9327eb1b1e36a21fdb71114be07434c0cc7bf63f6e1da274edebfe76f65fbd51ad2f14898b95b");
  ok &= verify_sha384("abc", "cb00753f45a35e8bb5a03d699ac65007272c32ab0eded1631a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7");
  ok &= verify_sha384("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
                      "3391fdddfc8dc7393707a65b1b4709397cf8b1d162af05abfe8f450de5f36bc6b0455a8520bc4e6f5fe95b1fe3c8452b");

  // SHA-512 Test Vectors
  ok &= verify_sha512("", "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e");
  ok &= verify_sha512("abc", "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f");
  ok &= verify_sha512("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
                      "204a8fc6dda82f0a0ced7beb8e08a41657c16ef468b228a8279be331a703c33596fd15c13b1b07f9aa1d3bea57789ca031ad85c7a71dd70354ec631238ca3445");

  if (ok) {
    printf("All SHA-2 test vectors passed.\n");
    return 0;
  }
  return 1;
}
