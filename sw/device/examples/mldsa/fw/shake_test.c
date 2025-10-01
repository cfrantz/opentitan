#include "sw/device/lib/base/status.h"
#include "sw/device/silicon_creator/lib/drivers/kmac.h"
#include "sw/device/silicon_creator/lib/dbg_print.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"

OTTF_DEFINE_TEST_CONFIG();

status_t shake128_xof(const char *input, size_t input_len, size_t nblocks) {
  TRY(kmac_shake128_configure());
  TRY(kmac_shake256_start());
  kmac_shake256_absorb((const uint8_t*)input, input_len);
  kmac_shake256_squeeze_start();

  for(size_t n=0; n<nblocks; ++n) {
    uint32_t output[0xa8 /sizeof(uint32_t)];
    TRY(kmac_shake256_squeeze(output, sizeof(output)/4));
    dbg_printf("Shake128 Block %u\r\n", n);
    dbg_hexdump(output, sizeof(output));
  }
  TRY(kmac_shake256_end());
  return OK_STATUS();
}

status_t shake256_xof(const char *input, size_t input_len, size_t nblocks) {
  TRY(kmac_shake256_configure());
  TRY(kmac_shake256_start());
  kmac_shake256_absorb((const uint8_t*)input, input_len);
  kmac_shake256_squeeze_start();

  for(size_t n=0; n<nblocks; ++n) {
    uint32_t output[0x88 /sizeof(uint32_t)];
    TRY(kmac_shake256_squeeze(output, sizeof(output)/4));
    dbg_printf("Shake256 Block %u\r\n", n);
    dbg_hexdump(output, sizeof(output));
  }
  TRY(kmac_shake256_end());
  return OK_STATUS();
}

status_t shake_test(void) {
  TRY(shake128_xof("hello", 5, 2));
  TRY(shake256_xof("hello", 5, 2));
  return OK_STATUS();
}

bool test_main(void) {
  status_t result = shake_test();
  return status_ok(result);
}
