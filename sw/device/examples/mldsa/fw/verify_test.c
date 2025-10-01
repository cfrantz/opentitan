#include "sw/device/lib/base/status.h"
#include "sw/device/silicon_creator/lib/dbg_print.h"
#include "sw/device/silicon_creator/lib/drivers/ibex.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"

#include "sw/device/examples/mldsa/ref/api.h"

#include "sw/device/examples/mldsa/data/foo_pk.h"
#include "sw/device/examples/mldsa/data/message.h"
#include "sw/device/examples/mldsa/data/signature.h"

OTTF_DEFINE_TEST_CONFIG();

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

status_t verify_test(void) {
  uint32_t start = ibex_mcycle32();
  int result = pqcrystals_ml_dsa_87_ref_verify(
      message_sig, sizeof(message_sig),
      message_txt, sizeof(message_txt),
      (const uint8_t*)"", 0,
      foo_pk);
  uint32_t end = ibex_mcycle32();
  dbg_printf("Verify result: %d in %u cycles\n", result, end-start);
  return OK_STATUS();
}

bool test_main(void) {
  status_t result = verify_test();
  return status_ok(result);
}
