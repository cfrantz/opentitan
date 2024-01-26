// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_XMODEM_H_
#define OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_XMODEM_H_

#include <stdint.h>

#include "sw/device/lib/base/hardened.h"
#include "sw/device/silicon_creator/lib/error.h"

/**
 * Send the Xmodem-CRC start sequence.
 */
void xmodem_recv_start(void);

/**
 * Acknowledge an Xmodem frame.
 *
 * @param ack Whether to ACK (true) or NAK (false).
 */
void xmodem_ack(bool ack);

/**
 * Receive a frame using Xmodem-CRC
 *
 * @param frame The frame number expected (start at 1).
 * @param data Buffer to receive the data into.
 * @param rxlen The length of data recieved.
 * @param unknown_rx The byte received when the error is kErrorXmodemUnknown.
 * @return Error value.
 */
rom_error_t xmodem_recv_frame(uint32_t frame, uint8_t *data, size_t *rxlen,
                              uint8_t *unknown_rx);

/**
 * Send data using Xmodem-CRC.
 *
 * Sends a buffer of data using Xmodem-CRC.
 *
 * @param data buffer to send.
 * @param len length of the buffer.
 * @return Error value.
 */
rom_error_t xmodem_send(const void *data, size_t len);

#endif  // OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_XMODEM_H_
