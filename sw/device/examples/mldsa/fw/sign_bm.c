#include "sw/device/silicon_creator/lib/dbg_print.h"
#include "sw/device/silicon_creator/lib/drivers/ibex.h"
#include "sw/device/silicon_creator/lib/stack_utilization.h"

#include "sw/device/examples/mldsa/ref/api.h"
#include "sw/device/examples/mldsa/ref/config.h"

#include "sw/device/examples/mldsa/data/mldsa87/foo_sk.h"
#include "sw/device/examples/mldsa/data/mldsa87/message.h"
#include "sw/device/examples/mldsa/data/mldsa87/signature.h"


const char kBase64[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static void base64_encode(const uint8_t *data, int32_t len) {
  for (int32_t i = 0; len > 0; i += 3, len -= 3) {
    // clang-format off
    uint32_t val = (uint32_t)(data[i] << 16 |
                              (len > 1 ? data[i + 1] << 8 : 0) |
                              (len > 2 ? data[i + 2] : 0));
    // clang-format on
    dbg_printf("%c", kBase64[(val >> 18) & 0x3f]);
    dbg_printf("%c", kBase64[(val >> 12) & 0x3f]);
    dbg_printf("%c", len > 1 ? kBase64[(val >> 6) & 0x3f] : '=');
    dbg_printf("%c", len > 2 ? kBase64[(val >> 0) & 0x3f] : '=');
  }
  dbg_printf("\r\n");
}

/*
 * Sign size estimate:
 * - sign.o: 1118 bytes (.text)
 * - packing.o: 342 bytes (.text)
 * - poly.o: 1716 bytes (.text)
 * - polyvec.o: 1156 bytes (.text)
 * - reduce.o: 68 bytes (.text)
 * - rounding.o: 106 bytes (.text)
 * - symmetric-shake.o: 116 bytes (.text)
 * - ntt.o: 338 bytes (.text) + 1024 bytes (.rodata)
 * - shake.o: 400 bytes (.text)
 * - kmac.o: 924 bytes (.text)
 *
 * Totals:
 *   6284 bytes (.text) + 1024 bytes (.rodata)
 */

uint8_t sig[DILITHIUM_NAMESPACE(BYTES)];
int sign_test(void) {
  size_t siglen = sizeof(sig);

  uint32_t start = ibex_mcycle32();
  int result = DILITHIUM_NAMESPACE(signature(
      sig, &siglen,
      message_txt, sizeof(message_txt),
      (const uint8_t*)"", 0,
      foo_sk));
  uint32_t end = ibex_mcycle32();
  dbg_printf("Sign result: %d in %u cycles\n", result, end-start);
  base64_encode(sig, sizeof(sig));
  return result;
}

void bare_metal_main(void) {
  extern uint32_t _bss_end[];
  dbg_printf("dilithium_mode = %d\r\n", DILITHIUM_MODE);
  int result = sign_test();
  _stack_utilization_print(_bss_end);
  if (result == 0) {
    dbg_printf("PASS!\r\n");
  } else {
    dbg_printf("FAIL!\r\n");
  }
}
