// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <stdbool.h>
#include <stdint.h>

#include "sw/device/lib/arch/device.h"
#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/base/mmio.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/runtime/print.h"
#include "sw/device/lib/testing/test_main.h"
#include "sw/device/silicon_creator/lib/drivers/hmac.h"

#include "hw/top_earlgrey/sw/autogen/top_earlgrey.h"

const char kGettysburgPrelude[] =
    "Four score and seven years ago our fathers brought forth on this "
    "continent, a new nation, conceived in Liberty, and dedicated to the "
    "proposition that all men are created equal.";

// The following shell command will produce the sha256sum, although the words
// will be in the reverse order that  they appear in the digest array
// returned by `hmac_sha256_final`.
//
// $ echo -n "Four score and seven years ago our fathers brought forth on this
// continent, a new nation, conceived in Liberty, and dedicated to the
// proposition that all men are created equal." | \
//     sha256sum - | \
//     cut -f1 -d' ' | \
//     sed -e "s/......../0x&, /g"
//
// Since the shell command above emits the words in reversed order, we store
// them here in reversed order and perform the test with that in mind.
uint32_t kGettysburgDigest[] = {
    0x1e6fd403, 0x0f9034cd, 0x775708a3, 0x96c324ed,
    0x420ec587, 0xeb3dd433, 0xe29f6ac0, 0x8b8cc7ba,
};

rom_error_t hmac_test(void) {
  hmac_sha256_init();
  RETURN_IF_ERROR(hmac_sha256_update(kGettysburgPrelude,
                                     sizeof(kGettysburgPrelude) - 1));

  hmac_digest_t digest;
  RETURN_IF_ERROR(hmac_sha256_final(&digest));

  const size_t len = ARRAYSIZE(digest.digest);
  for (int i = 0; i < len; i++) {
    LOG_INFO("word %d = 0x%08x", i, digest.digest[i]);
    if (digest.digest[i] != kGettysburgDigest[len - 1 - i]) {
      return kErrorUnknown;
    }
  }
  return kErrorOk;
}

const test_config_t kTestConfig;

bool test_main(void) {
  rom_error_t result = hmac_test();
  return result == kErrorOk;
}
