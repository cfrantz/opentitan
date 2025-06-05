// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <stdio.h>

#include "sw/device/silicon_creator/manuf/base/perso_tlv_data.h"
#include "sw/device/silicon_creator/lib/error.h"


const char kBase64[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static void base64_encode(char *dest, const uint8_t *data, int32_t len) {
  for (int32_t i = 0; len > 0; i += 3, len -= 3) {
    // clang-format off
    uint32_t val = (uint32_t)(data[i] << 16 |
                              (len > 1 ? data[i + 1] << 8 : 0) |
                              (len > 2 ? data[i + 2] : 0));
    // clang-format on
    *dest++ = kBase64[(val >> 18) & 0x3f];
    *dest++ = kBase64[(val >> 12) & 0x3f];
    *dest++ = len > 1 ? kBase64[(val >> 6) & 0x3f] : '=';
    *dest++ = len > 2 ? kBase64[(val >> 0) & 0x3f] : '=';
  }
  *dest = '\0';
}

static void hexdump(const void *data, size_t len) {
  const uint8_t *d = (const uint8_t*)data;
  for(size_t i=0; i<len; ) {
    if (i%16 == 0) printf("%08lx: ", i);
    size_t j = 0;
    char buf[17] = {0};
    for(j=0; j<16 && i<len; ++i, ++j, ++d) {
      uint8_t val = *d;
      printf(" %02x", val);
      buf[j] = (val>=32 && val <127) ? val : '.';
    }
    for(;j<16; ++j) printf("   ");
    printf("  %s\n", buf);
  }
}

rom_error_t print_cert(uint8_t *data, size_t len) {
  char dest[3072];
  uint32_t offset = 0;
  hexdump(data, len);
  while(true) {
    perso_tlv_cert_obj_t obj = {0};
    rom_error_t err = perso_tlv_get_cert_obj(data + offset, len, &obj);
    if (err != kErrorOk) {
      printf("Error parsing at offset 0x%08x: 0x%08x\n", offset, err);
      return err;
    }

    base64_encode(dest, obj.cert_body_p, (int32_t)obj.cert_body_size);
    printf("%s offset=0x%08x type=%d sz=%zu\n", obj.name, offset, obj.obj_type, obj.obj_size);
    printf("-----BEGIN CERTIFICATE-----\n");
    printf("%s\n", dest);
    printf("-----END CERTIFICATE-----\n");
    offset += (obj.obj_size + 7) & ~7u;
    len -= obj.obj_size;
  }
  return kErrorOk;
}

int usage(char *prog) {
  printf("Usage:\n");
  printf("    %s [binary image from flash]\n", prog);
  return 1;
}

int main(int argc, char *argv[]) {
  if (argc != 2) {
    return usage(argv[0]);
  }

  FILE *fp = fopen(argv[1], "rb");
  if (fp == NULL) {
    perror("Could not open file");
    return 1;
  }

  uint8_t buf[4096];
  size_t len = fread(buf, 1, sizeof(buf), fp);
  fclose(fp);
  rom_error_t err = print_cert(buf, len);
  return err == kErrorOk;
}
