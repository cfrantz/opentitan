#include "sw/device/silicon_creator/lib/dbg_print.h"
#include "sw/device/silicon_creator/lib/drivers/ibex.h"
#include "sw/device/silicon_creator/lib/stack_utilization.h"

#include "sw/device/examples/slhdsa/ref/api.h"


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
 * Keygen size estimate:
 *
 * Totals:
 */
uint8_t sk[CRYPTO_SECRETKEYBYTES];
uint8_t pk[CRYPTO_PUBLICKEYBYTES];
void keygen(void) {
  uint64_t start = ibex_mcycle();
  int result = SPX_sha2_128s_simple_crypto_sign_keypair(pk, sk);
  uint64_t end = ibex_mcycle();
  uint64_t v = end - start;
  dbg_printf("Keygen result: %d in %u (0x%x%x) cycles\r\n", result, (uint32_t)v, (uint32_t)(v>>32), (uint32_t)(v));
  if (result == 0) {
    dbg_printf("SecretKey:\r\n");
    base64_encode(sk, sizeof(sk));
    dbg_printf("PublicKey:\r\n");
    base64_encode(pk, sizeof(pk));
  }
}

void bare_metal_main(void) {
  extern uint32_t _bss_end[];
  dbg_printf("slhdsa_mode = %s\r\n", xstr(NAMESPACE));
  keygen();
  _stack_utilization_print(_bss_end);
  dbg_printf("PASS!\r\n");
}
