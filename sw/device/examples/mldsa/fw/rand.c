#include "sw/device/examples/mldsa/fw/rand.h"

#include "sw/device/lib/base/abs_mmio.h"
#include "sw/device/silicon_creator/lib/drivers/ibex.h"
#include "hw/top_earlgrey/sw/autogen/top_earlgrey.h"
#include "rv_core_ibex_regs.h"

enum {
    kBaseIbex = TOP_EARLGREY_RV_CORE_IBEX_CFG_BASE_ADDR,

};

uint32_t rnd_uint32(void) {
  uint32_t mcycle = ibex_mcycle32();
  return mcycle + abs_mmio_read32(kBaseIbex + RV_CORE_IBEX_RND_DATA_REG_OFFSET);
}

void OQS_randombytes(uint8_t *output, size_t len) {
  while(len >= sizeof(uint32_t)) {
    uint32_t *v = (uint32_t*)output;
    *v = rnd_uint32();
    len -= 4;
    output += 4;
  }
  if (len) {
  uint32_t v = rnd_uint32();
  while(len) {
    *output++ = (uint8_t)v;
    len--;
    v>>=8;
  }
  }
}
