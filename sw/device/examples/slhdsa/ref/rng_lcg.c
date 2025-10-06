// A silly linear congruential generator.

#include <stdint.h>

#include "randombytes.h"

static uint32_t rando(void) {
    static uint32_t seed = 0xc0ffee;
    uint32_t val = seed;
    // 999331 and 19937 are both circular primes.
    // No particular methodology was used to pick them.
    seed = seed * 999331 + 19937;
    return val;
}

void randombytes(unsigned char *x, unsigned long xlen) {
  while(xlen > sizeof(uint32_t)) {
    uint32_t *p = (uint32_t*)x;
    *p = rando();
    x += sizeof(uint32_t);
    xlen -= sizeof(uint32_t);
  }
  while(xlen > 0) {
    *x = (uint8_t)rando();
    x += 1;
    xlen -= 1;
  }
}
