#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include "api.h"
#include "fips202.h"

void savebuf(const char *basename, const char *ext, void *buf, size_t n) {
    char fn[256];
    if (ext) {
      sprintf(fn, "%s.%s", basename, ext);
    } else {
      strcpy(fn, basename);
    }
    FILE *fp = fopen(fn, "wb");
    if (fp == NULL) {
      printf("Could not open %s for writing\n", fn);
      perror("fopen");
      exit(2);
    }
    fwrite(buf, 1, n, fp);
    fclose(fp);
}

size_t loadbuf(const char *filename, void *buf, size_t n) {
    FILE *fp = fopen(filename, "rb");
    n = fread(buf, 1, n, fp);
    if (ferror(fp)) {
      perror("fread");
      exit(2);
    }
    fclose(fp);
    return n;
}

void hexdump(const void *data, size_t len) {
  const uint8_t *d = (const uint8_t *)data;
  for(size_t i=0; i<len;) {
    printf("%08lx: ", i);
    size_t j;
    char buf[17] = {0};
    for(j=0; j<16 && i<len; ++i, ++j, ++d) {
      uint8_t val = *d;
      printf("%02x ", val);
      buf[j] = (val>=32 && val<127) ? val : '.';
    }
    while(j++<16) printf("   ");
    printf(" %s\n", buf);
  }
}

void keygen(const char *basename) {
  uint8_t sk[pqcrystals_ml_dsa_87_SECRETKEYBYTES];
  uint8_t pk[pqcrystals_ml_dsa_87_PUBLICKEYBYTES];


    if (pqcrystals_ml_dsa_87_ref_keypair(pk, sk) != 0) {
      printf("keygen error\n");
      exit(2);
    }
    savebuf(basename, "pk", pk, sizeof(pk));
    savebuf(basename, "sk", sk, sizeof(sk));
}

void sign(const char *skfile, const char *msgfile, const char *sigfile, const char *ctx) {
  uint8_t sk[pqcrystals_ml_dsa_87_SECRETKEYBYTES];
  size_t n = loadbuf(skfile, sk, sizeof(sk));
  if (n != sizeof(sk)) {
    printf("secretkey: loaded %zu bytes but wanted %zu\n", n, sizeof(sk));
    exit(2);
  }

  uint8_t msg[65536];
  n = loadbuf(msgfile, msg, sizeof(msg));
  printf("Loaded message: %zu bytes\n", n);

  uint8_t sig[pqcrystals_ml_dsa_87_BYTES];
  size_t siglen = sizeof(sig);
  pqcrystals_ml_dsa_87_ref_signature(sig, &siglen,
                                     msg, n,
                                     (const uint8_t*)ctx, strlen(ctx),
                                     sk);
  printf("Generated signatured of %zu bytes\n", siglen);
  savebuf(sigfile, NULL, sig, siglen);
}

void verify(const char *pkfile, const char *msgfile, const char *sigfile, const char *ctx) {
  uint8_t pk[pqcrystals_ml_dsa_87_PUBLICKEYBYTES];
  size_t n = loadbuf(pkfile, pk, sizeof(pk));
  if (n != sizeof(pk)) {
    printf("publickey: loaded %zu bytes but wanted %zu\n", n, sizeof(pk));
    exit(2);
  }

  uint8_t msg[65536];
  n = loadbuf(msgfile, msg, sizeof(msg));
  printf("Loaded message: %zu bytes\n", n);

  uint8_t sig[pqcrystals_ml_dsa_87_BYTES];
  size_t siglen = loadbuf(sigfile, sig, sizeof(sig));
  if (siglen != sizeof(sig)) {
    printf("sig: loaded %zu bytes but wanted %zu\n", siglen, sizeof(sig));
    exit(2);
  }

  int result = pqcrystals_ml_dsa_87_ref_verify(sig, siglen,
                                     msg, n,
                                     (const uint8_t*)ctx, strlen(ctx),
                                     pk);
  printf("Verify result: %d\n", result);
}

void shake128_xof(const char *input, size_t nblocks) {
  shake128incctx state;
  shake128_inc_init(&state);
  shake128_inc_absorb(&state, (const uint8_t*)input, strlen(input));
  shake128_inc_finalize(&state);

  for(size_t n=0; n<nblocks; ++n) {
    uint8_t output[SHAKE128_RATE];
    printf("Block %zu:\n", n);
    shake128_inc_squeeze(output, sizeof(output), &state);
    hexdump(output, sizeof(output));
  }
}

void shake256_xof(const char *input, size_t nblocks) {
  shake256incctx state;
  shake256_inc_init(&state);
  shake256_inc_absorb(&state, (const uint8_t*)input, strlen(input));
  shake256_inc_finalize(&state);

  for(size_t n=0; n<nblocks; ++n) {
    uint8_t output[SHAKE256_RATE];
    printf("Block %zu:\n", n);
    shake256_inc_squeeze(output, sizeof(output), &state);
    hexdump(output, sizeof(output));
  }
}

int usage(const char *prog) {
  printf("%s - mldsa demo program\n\n", prog);
  printf("%s keygen [basename] - generate a public and secret key\n", prog);
  printf("%s sign [secretkey] [message] [sigfile] - sign a message\n", prog);
  printf("%s verify [publickey] [message] [sigfile] - verify a message\n", prog);
  printf("%s shake128 [input] [nblocks] - Compute nblocks of shake128 output\n", prog);
  printf("%s shake256 [input] [nblocks] - Compute nblocks of shake256 output\n", prog);
  return 1;
}

int main(int argc, char *argv[]) {
  if (argc == 3 && !strcmp(argv[1], "keygen")) {
    keygen(argv[2]);
  } else if (argc == 5 && !strcmp(argv[1], "sign")) {
    sign(argv[2], argv[3], argv[4], "");
  } else if (argc == 5 && !strcmp(argv[1], "verify")) {
    verify(argv[2], argv[3], argv[4], "");
  } else if (argc == 4 && !strcmp(argv[1], "shake128")) {
    shake128_xof(argv[2], strtoul(argv[3], 0, 0));
  } else if (argc == 4 && !strcmp(argv[1], "shake256")) {
    shake256_xof(argv[2], strtoul(argv[3], 0, 0));
  } else {
    return usage(argv[0]);
  }
  return 0;
}
