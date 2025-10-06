#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include "api.h"

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

void keygen(const char *basename) {
  uint8_t pk[CRYPTO_PUBLICKEYBYTES];
  uint8_t sk[CRYPTO_SECRETKEYBYTES];
  SPX_sha2_128s_simple_crypto_sign_keypair(pk, sk);
  printf("Generated keypair (pk=%zu, sk=%zu)\n", sizeof(pk), sizeof(sk));
  savebuf(basename, "pk", pk, sizeof(pk));
  savebuf(basename, "sk", sk, sizeof(sk));
}

void sign(const char *skfile, const char *msgfile, const char *sigfile) {
  uint8_t sk[CRYPTO_SECRETKEYBYTES];
  size_t n = loadbuf(skfile, sk, sizeof(sk));
  if (n != sizeof(sk)) {
    printf("secretkey: loaded %zu bytes but wanted %zu\n", n, sizeof(sk));
    exit(2);
  }

  uint8_t msg[65536];
  n = loadbuf(msgfile, msg, sizeof(msg));
  printf("Loaded message: %zu bytes\n", n);

  uint8_t sig[CRYPTO_BYTES];
  size_t siglen = 0;

  SPX_sha2_128s_simple_crypto_sign_signature(sig, &siglen, msg, n, sk);

  printf("Generated signatured of %zu bytes\n", siglen);
  savebuf(sigfile, NULL, sig, siglen);
}

void verify(const char *pkfile, const char *msgfile, const char *sigfile) {
  uint8_t pk[CRYPTO_PUBLICKEYBYTES];
  size_t n = loadbuf(pkfile, pk, sizeof(pk));
  if (n != sizeof(pk)) {
    printf("publickey: loaded %zu bytes but wanted %zu\n", n, sizeof(pk));
    exit(2);
  }

  uint8_t msg[65536];
  n = loadbuf(msgfile, msg, sizeof(msg));
  printf("Loaded message: %zu bytes\n", n);

  uint8_t sig[CRYPTO_BYTES];
  size_t siglen = loadbuf(sigfile, sig, sizeof(sig));
  if (siglen != sizeof(sig)) {
    printf("sig: loaded %zu bytes but wanted %zu\n", siglen, sizeof(sig));
    exit(2);
  }

  int result = SPX_sha2_128s_simple_crypto_sign_verify(sig, siglen, msg, n, pk);
  printf("Verify result: %d\n", result);
}

int usage(const char *prog) {
  printf("%s - slh-dsa demo program\n\n", prog);
  printf("%s keygen [basename] benerate a public and secret key\n", prog);
  printf("%s sign [secretkey] [message] [sigfile] - sign a message\n", prog);
  printf("%s verify [publickey] [message] [sigfile] - verify a message\n", prog);
  return -1;
}

int main(int argc, char *argv[]) {
  if (argc == 3 && !strcmp(argv[1], "keygen")) {
    keygen(argv[2]);
  } else if (argc == 5 && !strcmp(argv[1], "sign")) {
    sign(argv[2], argv[3], argv[4]);
  } else if (argc == 5 && !strcmp(argv[1], "verify")) {
    verify(argv[2], argv[3], argv[4]);
  } else {
    return usage(argv[0]);
  }
  return 0;
}
