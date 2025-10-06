#include "sw/device/silicon_creator/lib/dbg_print.h"
#include "sw/device/silicon_creator/lib/drivers/ibex.h"
#include "sw/device/silicon_creator/lib/stack_utilization.h"

#include "sw/device/examples/slhdsa/ref/api.h"

#include "sw/device/examples/slhdsa/data/sha2_128s_simple/foo_pk.h"
#include "sw/device/examples/slhdsa/data/sha2_128s_simple/message.h"
#include "sw/device/examples/slhdsa/data/sha2_128s_simple/signature.h"

/*
 * Code size estimate for verify:
 */

int verify_test(void) {
  uint32_t start = ibex_mcycle32();
  int result = SPX_sha2_128s_simple_crypto_sign_verify(message_sig, sizeof(message_sig), message_txt, sizeof(message_txt), foo_pk);
  uint32_t end = ibex_mcycle32();
  dbg_printf("Verify result: %d in %u cycles\r\n", result, end-start);
  return result;
}

void bare_metal_main(void) {
  extern uint32_t _bss_end[];
  dbg_printf("slhdsa_mode = %s\r\n", xstr(NAMESPACE));
  int result = verify_test();
  _stack_utilization_print(_bss_end);
  if (result == 0) {
    dbg_printf("PASS!\r\n");
  } else {
    dbg_printf("FAIL!\r\n");
  }
}
