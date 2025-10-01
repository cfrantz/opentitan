#include "sw/device/examples/mldsa/fw/fips202.h"

#include "sw/device/silicon_creator/lib/drivers/kmac.h"
#include "sw/device/silicon_creator/lib/dbg_print.h"
#include "sw/device/silicon_creator/lib/error.h"

static int nested_init;

//void check_nested(int line) {
//  if (nested_init) dbg_printf("check nested init line=%d: %d\r\n", line, nested_init);
//}

static inline void unimp(void) {
  asm volatile("unimp" : : : "memory");
}


void shake128_inc_init(shake128_inc_ctx *state) {
  if (nested_init++) {
    dbg_printf("shake128 nested init: %d @ %x\r\n", nested_init, depth());
    unimp();
  }
  rom_error_t result;
  result = kmac_shake128_configure();
  if (result != kErrorOk) { dbg_printf("shake128_configure: %x\r\n", result); }
  result = kmac_shake256_start();
  if (result != kErrorOk) { dbg_printf("shake128_start: %x\r\n", result); }
}

void shake128_inc_absorb(shake128_inc_ctx *state, const uint8_t *input, size_t inlen) {
  kmac_shake256_absorb((const uint8_t*)input, inlen);
}

void shake128_inc_finalize(shake128_inc_ctx *state) {
  kmac_shake256_squeeze_start();
}

void shake128_inc_squeeze(uint8_t *output, size_t outlen, shake128_inc_ctx *state) {
  rom_error_t result;
  result = kmac_shake256_squeeze((uint32_t*)output, outlen/4);
  if (result != kErrorOk) { dbg_printf("shake128_squeeze: %x\r\n", result); }
}

void shake128_inc_ctx_release(shake128_inc_ctx *state) {
  nested_init--;
  rom_error_t result;
  result = kmac_shake256_end();
  if (result != kErrorOk) { dbg_printf("shake128_release: %x\r\n", result); }
}

void shake128_inc_ctx_reset(shake128_inc_ctx *state) {
  shake128_inc_ctx_release(state);
  shake128_inc_init(state);
}



void shake256_inc_init(shake256_inc_ctx *state) {
  if (nested_init++) {
    dbg_printf("shake256 nested init: %d @ %x\r\n", nested_init, depth());
    unimp();
  }

  rom_error_t result;
  result = kmac_shake256_configure();
  if (result != kErrorOk) { dbg_printf("shake256_configure: %x\r\n", result); }
  result = kmac_shake256_start();
  if (result != kErrorOk) { dbg_printf("shake256_start: %x\r\n", result); }
}

void shake256_inc_absorb(shake256_inc_ctx *state, const uint8_t *input, size_t inlen) {
  kmac_shake256_absorb((const uint8_t*)input, inlen);
}

void shake256_inc_finalize(shake256_inc_ctx *state) {
  kmac_shake256_squeeze_start();
}

void shake256_inc_squeeze(uint8_t *output, size_t outlen, shake256_inc_ctx *state) {
  rom_error_t result;
  result = kmac_shake256_squeeze((uint32_t*)output, outlen/4);
  if (result != kErrorOk) { dbg_printf("shake256_squeeze: %x\r\n", result); }
}

void shake256_inc_ctx_release(shake256_inc_ctx *state) {
  nested_init--;
  rom_error_t result;
  result = kmac_shake256_end();
  if (result != kErrorOk) { dbg_printf("shake256_release: %x\r\n", result); }
}

void shake256_inc_ctx_reset(shake256_inc_ctx *state) {
  shake256_inc_ctx_release(state);
  shake256_inc_init(state);
}

void shake256(uint8_t *output, size_t outlen, const uint8_t *input, size_t inplen) {
  shake256_inc_ctx state;
  shake256_inc_init(&state);
  shake256_inc_absorb(&state, input, inplen);
  shake256_inc_finalize(&state);
  shake256_inc_squeeze(output, outlen, &state);
  shake256_inc_ctx_release(&state);
}
