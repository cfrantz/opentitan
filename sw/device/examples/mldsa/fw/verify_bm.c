#include "sw/device/silicon_creator/lib/dbg_print.h"
#include "sw/device/silicon_creator/lib/drivers/ibex.h"
#include "sw/device/silicon_creator/lib/stack_utilization.h"


#include "sw/device/examples/mldsa/ref/api.h"
#include "sw/device/examples/mldsa/ref/config.h"

#if DILITHIUM_MODE == 2
#include "sw/device/examples/mldsa/data/mldsa44/foo_pk.h"
#include "sw/device/examples/mldsa/data/mldsa44/message.h"
#include "sw/device/examples/mldsa/data/mldsa44/signature.h"
#elif DILITHIUM_MODE == 3
#include "sw/device/examples/mldsa/data/mldsa65/foo_pk.h"
#include "sw/device/examples/mldsa/data/mldsa65/message.h"
#include "sw/device/examples/mldsa/data/mldsa65/signature.h"
#elif DILITHIUM_MODE == 5
#include "sw/device/examples/mldsa/data/mldsa87/foo_pk.h"
#include "sw/device/examples/mldsa/data/mldsa87/message.h"
#include "sw/device/examples/mldsa/data/mldsa87/signature.h"
#endif


/*
 * Code size estimate for ml_dsa_87_verify:
 * mldsa/ref:
 * - sign.o: 688 bytes (.text)
 * - packing.o: 388 bytes (.text)
 * - poly.o: 1120 bytes (.text)
 * - polyvec.o: 738 bytes (.text)
 * - reduce.o: 68 bytes (.text)
 * - rounding.o: 84 bytes (.text)
 * - symmetric-shake.o: 58 bytes (.text)
 * - ntt.o: 338 bytes (.text) + 1024 bytes (.rodata)
 * other firmware:
 * - shake.o: 430 bytes (.text)
 * - kmac.o: 806 bytes (.text)
 *
 * Totals: 4718 bytes (.text) + 1024 bytes (.rodata)
 *
 * Most of `shake.o` is adapter functions between the implementation's use of
 * shake and the functions provided by our kmac driver.
 */

int verify_test(void) {
  uint32_t start = ibex_mcycle32();
  int result = DILITHIUM_NAMESPACE(verify(
      message_sig, sizeof(message_sig),
      message_txt, sizeof(message_txt),
      (const uint8_t*)"", 0,
      foo_pk));
  uint32_t end = ibex_mcycle32();
  dbg_printf("Verify result: %d in %u cycles\n", result, end-start);
  return result;
}

void bare_metal_main(void) {
  extern uint32_t _bss_end[];
  dbg_printf("dilithium_mode = %d\r\n", DILITHIUM_MODE);
  int result = verify_test();
  _stack_utilization_print(_bss_end);
  if (result == 0) {
    dbg_printf("PASS!\r\n");
  } else {
    dbg_printf("FAIL!\r\n");
  }
}
