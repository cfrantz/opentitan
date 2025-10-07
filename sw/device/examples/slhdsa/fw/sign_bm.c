#include "sw/device/silicon_creator/lib/dbg_print.h"
#include "sw/device/silicon_creator/lib/drivers/ibex.h"
#include "sw/device/silicon_creator/lib/stack_utilization.h"

#include "sw/device/examples/slhdsa/ref/api.h"

#ifndef SPX_Q20
#include "sw/device/examples/slhdsa/data/sha2_128s_simple/foo_sk.h"
#include "sw/device/examples/slhdsa/data/sha2_128s_simple/message.h"
#include "sw/device/examples/slhdsa/data/sha2_128s_simple/signature.h"
#else
#include "sw/device/examples/slhdsa/data/sha2_128s_simple_q20/foo_sk.h"
#include "sw/device/examples/slhdsa/data/sha2_128s_simple_q20/message.h"
#include "sw/device/examples/slhdsa/data/sha2_128s_simple_q20/signature.h"
#endif


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
 */

uint8_t sig[CRYPTO_BYTES];
int sign_test(void) {
  size_t siglen = sizeof(sig);

  uint64_t start = ibex_mcycle();
  int result = SPX_sha2_128s_simple_crypto_sign_signature(sig, &siglen, message_txt, sizeof(message_txt), foo_sk);
  uint64_t end = ibex_mcycle();
  uint64_t v = end-start;
  dbg_printf("Keygen result: %d in %u (0x%x%x) cycles\r\n", result, (uint32_t)v, (uint32_t)(v>>32), (uint32_t)(v));
  base64_encode(sig, sizeof(sig));
  return result;
}

void bare_metal_main(void) {
  extern uint32_t _bss_end[];
  dbg_printf("slhdsa_mode = %s\r\n", xstr(NAMESPACE));
  int result = sign_test();
  _stack_utilization_print(_bss_end);
  if (result == 0) {
    dbg_printf("PASS!\r\n");
  } else {
    dbg_printf("FAIL!\r\n");
  }
}
