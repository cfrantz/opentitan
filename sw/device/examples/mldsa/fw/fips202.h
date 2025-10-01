#ifndef LOCAL_GOOGLE_HOME_CFRANTZ_OPENTITAN_SPX_SW_DEVICE_EXAMPLES_MLDSA_FW_FIPS202_H_
#define LOCAL_GOOGLE_HOME_CFRANTZ_OPENTITAN_SPX_SW_DEVICE_EXAMPLES_MLDSA_FW_FIPS202_H_
#include <stdint.h>
#include <stddef.h>


static inline uint32_t depth(void) {
  uint32_t sp;
  sp = (uint32_t)&sp;
  return sp;
}


#define SHAKE128_RATE (1344/8)
#define SHAKE256_RATE (1088/8)

typedef struct { char zz; } shake128_inc_ctx;
typedef struct { char zz; } shake256_inc_ctx;

typedef shake128_inc_ctx shake128incctx;
typedef shake256_inc_ctx shake256incctx;

void shake128_inc_init(shake128_inc_ctx *state) ;
void shake128_inc_absorb(shake128_inc_ctx *state, const uint8_t *input, size_t inlen) ;
void shake128_inc_finalize(shake128_inc_ctx *state) ;
void shake128_inc_squeeze(uint8_t *output, size_t outlen, shake128_inc_ctx *state) ;
void shake128_inc_ctx_release(shake128_inc_ctx *state) ;
void shake128_inc_ctx_reset(shake128_inc_ctx *state) ;

void shake256_inc_init(shake256_inc_ctx *state) ;
void shake256_inc_absorb(shake256_inc_ctx *state, const uint8_t *input, size_t inlen) ;
void shake256_inc_finalize(shake256_inc_ctx *state) ;
void shake256_inc_squeeze(uint8_t *output, size_t outlen, shake256_inc_ctx *state) ;
void shake256_inc_ctx_release(shake256_inc_ctx *state) ;
void shake256_inc_ctx_reset(shake256_inc_ctx *state) ;

void shake256(uint8_t *output, size_t outlen, const uint8_t *input, size_t inplen);

#define shake128_squeezeblocks(OUT, NBLOCKS, STATE) \
        shake128_inc_squeeze(OUT, (NBLOCKS)*SHAKE128_RATE, STATE)

#define shake256_squeezeblocks(OUT, NBLOCKS, STATE) \
        shake256_inc_squeeze(OUT, (NBLOCKS)*SHAKE256_RATE, STATE)


#endif  // LOCAL_GOOGLE_HOME_CFRANTZ_OPENTITAN_SPX_SW_DEVICE_EXAMPLES_MLDSA_FW_FIPS202_H_
