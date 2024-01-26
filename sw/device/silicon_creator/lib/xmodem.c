// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/silicon_creator/lib/xmodem.h"

#include "sw/device/silicon_creator/lib/drivers/uart.h"

/**
 * Constants used in the XModem-CRC protocol.
 */
enum {
  kXModemCrc16 = 0x43,
  kXModemSoh = 0x01,
  kXModemStx = 0x02,
  kXModemEof = 0x04,
  kXModemAck = 0x06,
  kXModemNak = 0x15,
  kXModemCancel = 0x18,
  kXModemPoly = 0x1021,
  kXModemSendRetries = 3,
  kXModemMaxErrors = 2,
  kXModemShortTimeout = 100,
  kXModemLongTimeout = 1000,
};

/**
 * Calculates a CRC-16 using the XModem polynomial.
 */
static uint16_t crc16(uint16_t crc, const void *buf, size_t len) {
  const uint8_t *p = (const uint8_t *)buf;
  for (size_t i = 0; i < len; ++i, ++p) {
    crc ^= *p << 8;
    for (size_t j = 0; j < 8; ++j) {
      bool msb = (crc & 0x8000) != 0;
      crc <<= 1;
      if (msb)
        crc ^= kXModemPoly;
    }
  }
  return (uint16_t)crc;
}

/**
 * Calculate an XModem CRC16 for a to-be-transmitted block.
 */
static uint16_t crc16_block(const void *buf, size_t len, size_t block_sz) {
  uint16_t crc = crc16(0, buf, len);
  uint8_t pad = 0;
  for (; len < block_sz; ++len) {
    crc = crc16(crc, &pad, 1);
  }
  return crc;
}

void xmodem_recv_start(void) { uart_putchar(kXModemCrc16); }

void xmodem_ack(bool ack) { uart_putchar(ack ? kXModemAck : kXModemNak); }

rom_error_t xmodem_recv_frame(uint32_t frame, uint8_t *data, size_t *rxlen,
                              uint8_t *unknown_rx) {
  int ch;

  ch = uart_getchar(frame == 1 ? kXModemLongTimeout : kXModemShortTimeout);
  if (ch == -1) {
    return kErrorXModemTimeoutStart;
  } else if (ch == kXModemStx || ch == kXModemSoh) {
    // Determine if we should expect a 1K or 128 byte block.
    size_t len = ch == kXModemStx ? 1024 : 128;
    size_t n;
    uint8_t pkt[2];

    // Get the frame number and its inverse.
    n = uart_read(pkt, sizeof(pkt), kXModemShortTimeout);
    if (n != sizeof(pkt)) {
      return kErrorXModemTimeoutPacket;
    }

    // If the frame or its inverse are incorrect, cancel.
    bool cancel = pkt[0] != (uint8_t)frame || pkt[0] != 255 - pkt[1];

    // Receive the data.  At 115200 bps, 1K should take about 89ms to
    // receive a 1K frame.  A short timeout should be enough, but we'll
    // be generous and give more time.
    n = uart_read(data, len, kXModemShortTimeout * 3);
    if (n != len) {
      return kErrorXModemTimeoutData;
    }

    // Receive the CRC-16 from the client.
    n = uart_read(pkt, sizeof(pkt), kXModemShortTimeout);
    if (n != sizeof(pkt)) {
      return kErrorXModemTimeoutCrc;
    }
    if (cancel) {
      return kErrorXModemCancel;
    }

    // Compute our own CRC-16 and compare with the client's value.
    uint16_t crc = (uint16_t)(pkt[0] << 8 | pkt[1]);
    uint16_t val = crc16(0, data, len);
    if (crc != val) {
      return kErrorXModemCrc;
    }
    if (rxlen)
      *rxlen = len;
    return kErrorOk;
  } else if (ch == kXModemEof) {
    return kErrorXModemEndOfFile;
  } else {
    if (unknown_rx)
      *unknown_rx = (uint8_t)ch;
    return kErrorXModemUnknown;
  }
}

/**
 * Wait for the xmodem-crc start sequence.
 */
static rom_error_t xmodem_send_start(uint32_t retries) {
  int ch;
  int cancels = 0;
  for (uint32_t i = 0; i < retries; ++i) {
    ch = uart_getchar(kXModemLongTimeout);
    switch (ch) {
      case -1:
        continue;
      case kXModemCrc16:
        return kErrorOk;
      case kXModemNak:
        return kErrorXModemProtocol;
      case kXModemCancel:
        cancels += 1;
        if (cancels >= 2)
          return kErrorXModemCancel;
        break;
      default:
          /* Unknown character: do nothing */
          ;
    }
  }
  return kErrorXModemTimeoutStart;
}

static rom_error_t xmodem_send_finish(void) {
  uart_putchar(kXModemEof);
  int ch = uart_getchar(kXModemLongTimeout);
  if (ch != kXModemAck) {
    // Should have seen an ACK, but we don't really care since there is nothing
    // we could do about it.
  }
  return kErrorOk;
}

static rom_error_t xmodem_send_data(const void *data, size_t len,
                                    uint32_t max_errors) {
  const uint8_t *p = (const uint8_t *)data;
  uint32_t block = 0;
  uint32_t errors = 0;
  uint32_t cancels = 0;
  while (len) {
    uint32_t block_sz = len < 1024 ? 128 : 1024;
    uint32_t chunk = len < block_sz ? len : block_sz;
    block += 1;

    uint16_t crc = crc16_block(data, len, block_sz);
    while (true) {
      // Start an XModem-CRC frame according to size.
      // XModem-CRC supports both 128-byte and 1K frames.
      // Write the header: <Soh or Stx> <block> <inverse-of-block>
      uart_putchar(block_sz == 128 ? kXModemSoh : kXModemStx);
      uart_putchar((uint8_t)block);
      uart_putchar(255 - (uint8_t)block);
      // Write the data.
      uart_write(p, chunk);
      // Pad the block out to the block size.
      for (uint32_t i = chunk; i < block_sz; ++i) {
        uart_putchar(0);
      }
      // Write the CRC16 value.
      uart_putchar(crc >> 8);
      uart_putchar(crc & 0xFF);

      // Get and check the ACK.
      int ch = uart_getchar(kXModemShortTimeout);
      switch (ch) {
        case -1:
          return kErrorXModemTimeoutAck;
        case kXModemAck:
          goto next_block;
        case kXModemCancel:
          cancels += 1;
          if (cancels >= 2)
            return kErrorXModemCancel;
          break;
        case kXModemNak:
        default:
          errors += 1;
          break;
      }
      if (errors >= max_errors) {
        return kErrorXModemTooManyErrors;
      }
    }
  next_block:
    len -= chunk;
  }
  return kErrorOk;
}

rom_error_t xmodem_send(const void *data, size_t len) {
  HARDENED_RETURN_IF_ERROR(xmodem_send_start(kXModemSendRetries));
  HARDENED_RETURN_IF_ERROR(xmodem_send_data(data, len, kXModemMaxErrors));
  HARDENED_RETURN_IF_ERROR(xmodem_send_finish());
  return kErrorOk;
}
