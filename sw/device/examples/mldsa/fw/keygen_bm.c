#include "sw/device/silicon_creator/lib/dbg_print.h"
#include "sw/device/silicon_creator/lib/drivers/ibex.h"
#include "sw/device/silicon_creator/lib/stack_utilization.h"

#include "sw/device/examples/mldsa/ref/api.h"
#include "sw/device/examples/mldsa/ref/config.h"


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
 * - shake.o: 400 bytes (.text)
 * - kmac.o: 924 bytes (.text)
 *
 * Totals:
 */
uint8_t sk[DILITHIUM_NAMESPACE(SECRETKEYBYTES)];
uint8_t pk[DILITHIUM_NAMESPACE(PUBLICKEYBYTES)];
void keygen(void) {
  uint32_t start = ibex_mcycle32();
  int result = DILITHIUM_NAMESPACE(keypair(pk, sk));
  uint32_t end = ibex_mcycle32();
  dbg_printf("Keygen result: %d in %u cycles\n", result, end-start);
  if (result == 0) {
    dbg_printf("SecretKey:\r\n");
    base64_encode(sk, sizeof(sk));
    dbg_printf("PublicKey:\r\n");
    base64_encode(pk, sizeof(pk));
  }
}

void bare_metal_main(void) {
  extern uint32_t _bss_end[];
  dbg_printf("dilithium_mode = %d\r\n", DILITHIUM_MODE);
  keygen();
  _stack_utilization_print(_bss_end);
  dbg_printf("PASS!\r\n");
}
