// Opentitan Earlgrey's built-in random number generator

#include <stdint.h>

#include "randombytes.h"
#include "sw/device/silicon_creator/lib/drivers/rnd.h"

void randombytes(unsigned char *x, unsigned long xlen) {
  while(xlen > sizeof(uint32_t)) {
    uint32_t *p = (uint32_t*)x;
    *p = rnd_uint32();
    x += sizeof(uint32_t);
    xlen -= sizeof(uint32_t);
  }
  while(xlen > 0) {
    *x = (uint8_t)rnd_uint32();
    x += 1;
    xlen -= 1;
  }
}
