// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/silicon_creator/lib/drivers/usb.h"

#include "sw/device/lib/base/abs_mmio.h"
#include "sw/device/lib/base/bitfield.h"
#include "sw/device/lib/base/hardened.h"

#include "hw/top_earlgrey/sw/autogen/top_earlgrey.h"
#include "usbdev_regs.h"

#define USBDEV_NUM_BUFFERS 32
#define CFG_PIN_FLIP false
#define CFG_EN_DIFF_RCVR true
#define CFG_TX_USE_D_SE0 false

enum {
  kBase = TOP_EARLGREY_USBDEV_BASE_ADDR,
};

// The buffer_pool is a bitmap of allocated buffers.
// - One bits represent free buffers.
// - Zero bits represent allocated buffers.
static uint32_t buffer_pool;

static inline void buffer_pool_init(void) {
  // Our hardware has 32 buffers; set all one bits to indicate
  // all buffers are free.
  buffer_pool = UINT32_MAX;
}

static inline void buffer_pool_put(uint8_t id) {
  HARDENED_CHECK_NE(buffer_pool, UINT32_MAX);
  buffer_pool |= (1 << id);
}

static inline uint8_t buffer_pool_get(void) {
  HARDENED_CHECK_NE(buffer_pool, 0);
  uint8_t id = (uint8_t)bitfield_find_first_set32((int32_t)buffer_pool) - 1;
  buffer_pool &= ~(1 << id);
  return id;
}

static inline bool buffer_pool_empty(void) { return buffer_pool == 0; }

usb_ep_info_t in_endpoints[USBDEV_PARAM_N_ENDPOINTS];
usb_ep_info_t out_endpoints[USBDEV_PARAM_N_ENDPOINTS];

// Copy memory into a USB buffer.
// The USB register space only permits word writes, so we need to handle
// buffer lengths that are not perfect multiples of the word size.
static void copy_to_buffer(uint8_t id, const char *src, size_t len) {
  uintptr_t buffer = kBase + USBDEV_BUFFER_REG_OFFSET + (uint32_t)id * 64;
  volatile uint32_t *dst = (volatile uint32_t *)buffer;
  while (len >= sizeof(uint32_t)) {
    *dst++ = *(uint32_t *)src;
    src += sizeof(uint32_t);
    len -= sizeof(uint32_t);
  }
  uint32_t last = 0;
  uint32_t shift = 0;
  while (len > 0) {
    last |= (uint32_t)*src << shift;
    shift += 8;
    src += 1;
    len -= 1;
  }
  *dst = last;
}

// Copy from an USB buffer to memory.
// The USB register space only permits word writes, so we need to handle
// buffer lengths that are not perfect multiples of the word size.
static void copy_from_buffer(uint8_t id, char *dst, size_t len) {
  uintptr_t buffer = kBase + USBDEV_BUFFER_REG_OFFSET + (uint32_t)id * 64;
  volatile uint32_t *src = (volatile uint32_t *)buffer;

  uint32_t *dst32 = (uint32_t *)dst;
  while (len >= sizeof(uint32_t)) {
    *dst32++ = *src++;
    len -= sizeof(uint32_t);
  }
  if (len > 0) {
    uint32_t last = *src;
    dst = (char *)dst32;
    while (len > 0) {
      *dst++ = (char)last;
      last >>= 8;
      len -= 1;
    }
  }
}

// Configure the PHY according the define directives above.
static void usb_phy_init(void) {
  uint32_t phy_config = 0;
  phy_config = bitfield_bit32_write(
      phy_config, USBDEV_PHY_CONFIG_USE_DIFF_RCVR_BIT, CFG_EN_DIFF_RCVR);
  phy_config = bitfield_bit32_write(
      phy_config, USBDEV_PHY_CONFIG_TX_USE_D_SE0_BIT, CFG_TX_USE_D_SE0);
  phy_config = bitfield_bit32_write(
      phy_config, USBDEV_PHY_CONFIG_EOP_SINGLE_BIT_BIT, false);
  phy_config = bitfield_bit32_write(phy_config, USBDEV_PHY_CONFIG_PINFLIP_BIT,
                                    CFG_PIN_FLIP);
  // TODO: is this required?
  phy_config = bitfield_bit32_write(
      phy_config, USBDEV_PHY_CONFIG_USB_REF_DISABLE_BIT, true);
  abs_mmio_write32(kBase + USBDEV_PHY_CONFIG_REG_OFFSET, phy_config);
}

// Performa a read/modify/write on a given register.
static void usbreg_bit(uint32_t offset, uint32_t bit, bool value) {
  uint32_t reg = abs_mmio_read32(kBase + offset);
  reg = bitfield_bit32_write(reg, bit, value);
  abs_mmio_write32(kBase + offset, reg);
}

// Set or clear STALL on an endpoint.
rom_error_t usb_ep_stall(uint8_t ep, bool enable) {
  uint8_t i = ep & kEpNumMask;
  if (i >= USBDEV_PARAM_N_ENDPOINTS) {
    return kErrorUsbBadEndpointNumber;
  }
  if (ep & kUsbDirIn || in_endpoints[i].flags & kUsbEpFlagsControl) {
    usbreg_bit(USBDEV_IN_STALL_REG_OFFSET, i, enable);
  }
  if ((ep & kUsbDirIn) == 0) {
    usbreg_bit(USBDEV_OUT_STALL_REG_OFFSET, i, enable);
  }
  return kErrorOk;
}

// Return whether an endpoint is stalled.
rom_error_t usb_ep_stalled(uint8_t ep, bool *stalled) {
  uint32_t reg = ep & kUsbDirIn ? abs_mmio_read32(USBDEV_IN_STALL_REG_OFFSET)
                                : abs_mmio_read32(USBDEV_OUT_STALL_REG_OFFSET);
  uint8_t i = ep & kEpNumMask;
  if (i >= USBDEV_PARAM_N_ENDPOINTS) {
    return kErrorUsbBadEndpointNumber;
  }
  *stalled = (reg & (1 << i)) != 0;
  return kErrorOk;
}

rom_error_t usb_ep_init(uint8_t ep, usb_ep_flags_t flags, uint16_t size,
                        handler_t handler, void *user_ctx) {
  uint8_t i = ep & kEpNumMask;
  if (i >= USBDEV_PARAM_N_ENDPOINTS) {
    return kErrorUsbBadEndpointNumber;
  }
  // If this is an OUT endpoint, configure for out transactions,
  // but don't enable receive (we'll do that in usb_ep_transfer).
  if ((ep & kUsbDirIn) == 0 || flags & kUsbEpFlagsControl) {
    out_endpoints[i].flags = flags;
    out_endpoints[i].size = size;
    out_endpoints[i].transfer = (usb_transfer_t){0};
    out_endpoints[i].handler = handler;
    out_endpoints[i].user_ctx = user_ctx;

    usbreg_bit(USBDEV_EP_OUT_ENABLE_REG_OFFSET, i, true);
    usbreg_bit(USBDEV_SET_NAK_OUT_REG_OFFSET, i, false);
    // usbreg_bit(USBDEV_RXENABLE_OUT_REG_OFFSET, i, false);
  }
  // If this is a CONTROL endpoint (e.g. handles SETUP_DATA),
  // then enable SETUP and OUT.
  if (flags & kUsbEpFlagsControl) {
    usbreg_bit(USBDEV_RXENABLE_OUT_REG_OFFSET, i, true);
    usbreg_bit(USBDEV_RXENABLE_SETUP_REG_OFFSET, i, true);
  }
  // If this is an IN endpoint, enable for IN.
  if ((ep & kUsbDirIn) != 0 || flags & kUsbEpFlagsControl) {
    in_endpoints[i].flags = flags;
    in_endpoints[i].size = size;
    in_endpoints[i].transfer = (usb_transfer_t){0};
    in_endpoints[i].handler = handler;
    in_endpoints[i].user_ctx = user_ctx;

    usbreg_bit(USBDEV_EP_IN_ENABLE_REG_OFFSET, i, true);
  }

  // Clear stall.
  usb_ep_stall(ep, false);
  return kErrorOk;
}

void fill_fifos(void) {
  while (!buffer_pool_empty()) {
    uint32_t status = abs_mmio_read32(kBase + USBDEV_USBSTAT_REG_OFFSET);
    uint32_t av_setup_depth =
        bitfield_field32_read(status, USBDEV_USBSTAT_AV_SETUP_DEPTH_FIELD);
    if (av_setup_depth >= 2) {
      // Available SETUP Buffer FIFO is okay, what about the OUT buffers?
      bool av_out_full =
          bitfield_bit32_read(status, USBDEV_USBSTAT_AV_OUT_FULL_BIT);
      if (av_out_full) {
        break;
      }
    }
    uint8_t id = buffer_pool_get();
    if (av_setup_depth < 2) {
      // Supply Available SETUP Buffer
      abs_mmio_write32(kBase + USBDEV_AVSETUPBUFFER_REG_OFFSET, id);
    } else {
      // Supply Available OUT Buffer
      abs_mmio_write32(kBase + USBDEV_AVOUTBUFFER_REG_OFFSET, id);
    }
  }
}

static bool rx_fifo_empty(void) {
  uint32_t status = abs_mmio_read32(kBase + USBDEV_USBSTAT_REG_OFFSET);
  return bitfield_bit32_read(status, USBDEV_USBSTAT_RX_EMPTY_BIT);
}

static void send_packet(uint8_t ep_index) {
  usb_ep_info_t *endpoint = in_endpoints + ep_index;
  size_t chunk = endpoint->size < endpoint->transfer.len
                     ? endpoint->size
                     : endpoint->transfer.len;
  uint8_t buffer = buffer_pool_get();

  if (chunk < endpoint->size) {
    // If the chunk is shorter than the endpoint size, then we can
    // clear the ShortIn flag.
    endpoint->transfer.flags &= ~(uint32_t)kUsbTransactionFlagsShortIn;
  }
  copy_to_buffer(buffer, (char *)endpoint->transfer.data, chunk);
  endpoint->transfer.data += chunk;
  endpoint->transfer.len -= chunk;
  endpoint->transfer.bytes_transfered += chunk;

  uint32_t val = 0;
  val = bitfield_field32_write(val, USBDEV_CONFIGIN_0_BUFFER_0_FIELD, buffer);
  val = bitfield_field32_write(val, USBDEV_CONFIGIN_0_SIZE_0_FIELD, chunk);

  // Mark the packet as ready for transmission
  val = bitfield_bit32_write(val, USBDEV_CONFIGIN_0_RDY_0_BIT, true);
  abs_mmio_write32(
      kBase + USBDEV_CONFIGIN_0_REG_OFFSET + ep_index * sizeof(uint32_t), val);
}

rom_error_t usb_ep_transfer(uint8_t ep, void *data, size_t len,
                            usb_transaction_flags_t flags) {
  // Copy the direction from flags.
  ep |= flags & kUsbTransactionFlagsIn;
  uint8_t i = ep & kEpNumMask;
  if (i >= USBDEV_PARAM_N_ENDPOINTS) {
    return kErrorUsbBadEndpointNumber;
  }
  usb_ep_info_t *endpoint = ep & kUsbDirIn ? in_endpoints : out_endpoints;
  endpoint += i;

  if (endpoint->flags & kUsbEpFlagsControl && len > 0) {
    // Transfers of more than length zero on a control endpoint require a
    // zero-byte transfer in the opposite direction to finish the transaction.
    flags |= kUsbTransactionFlagsControl;
  }
  endpoint->transfer.data = (char *)data;
  endpoint->transfer.len = len;
  endpoint->transfer.bytes_transfered = 0;
  endpoint->transfer.flags = flags;
  if (ep & kUsbDirIn) {
    // IN transfer to host; send the first packet.
    send_packet(i);
  } else {
    // OUT transfer from host; enable receiving OUT packets.
    usbreg_bit(USBDEV_RXENABLE_OUT_REG_OFFSET, i, true);
  }
  return kErrorOk;
}

void usb_poll(void) {
  usb_setup_data_t setup_data = {0};
  uint32_t istate = abs_mmio_read32(kBase + USBDEV_INTR_STATE_REG_OFFSET);

  // Handle IN transactions: return sent buffers to the buffer pool and send the
  // next packet in any multi-packet transfers.
  if (bitfield_bit32_read(istate, USBDEV_INTR_COMMON_PKT_SENT_BIT)) {
    uint32_t sent = abs_mmio_read32(kBase + USBDEV_IN_SENT_REG_OFFSET);
    for (uint8_t ep = 0; sent && ep < USBDEV_PARAM_N_ENDPOINTS; ++ep) {
      if (sent & (1 << ep)) {
        usb_ep_info_t *endpoint = in_endpoints + ep;
        uint32_t reg = abs_mmio_read32(kBase + USBDEV_CONFIGIN_0_REG_OFFSET +
                                       ep * sizeof(uint32_t));
        uint8_t buffer = (uint8_t)bitfield_field32_read(
            reg, USBDEV_CONFIGIN_0_BUFFER_0_FIELD);
        buffer_pool_put(buffer);
        abs_mmio_write32(
            kBase + USBDEV_CONFIGIN_0_REG_OFFSET + ep * sizeof(uint32_t),
            1 << USBDEV_CONFIGIN_0_PEND_0_BIT);
        // Clear IN_SENT bit (rw1c).
        abs_mmio_write32(kBase + USBDEV_IN_SENT_REG_OFFSET, 1 << ep);

        if (endpoint->transfer.len > 0 ||
            (endpoint->transfer.len == 0 &&
             (endpoint->transfer.flags & kUsbTransactionFlagsShortIn))) {
          // If there is more data to transfer or if we need to send a zero-byte
          // IN packet to complete the transfer, then send the packet.
          send_packet(ep);
        } else {
          if (endpoint->transfer.flags & kUsbTransactionFlagsControl) {
            // If this is a control transfer, we need to turn around with a
            // zero-byte OUT packet.
            usb_ep_transfer(ep, NULL, 0, kUsbTransactionFlagsControlAck);
          } else {
            // Complete the transfer.
            if ((endpoint->flags & kUsbEpFlagsControl) == 0) {
              ep |= kUsbDirIn;
            }
            if (endpoint->transfer.flags & kUsbTransactionFlagsControlAck) {
              endpoint->transfer.flags = 0;
              endpoint = out_endpoints + ep;
            }
            endpoint->transfer.flags |= kUsbTransactionFlagsDone;
            endpoint->handler(endpoint->user_ctx, ep, endpoint->transfer.flags,
                              &endpoint->transfer.bytes_transfered);
          }
        }
        sent &= ~(1 << ep);
      }
    }
  }

  // Re-fill FIFOs as needed.
  fill_fifos();

  // Handle OUT transactions:
  // - Get SETUPDATA for control endpoints.
  // - Copy from USB buffers into the receiver's buffer.
  // - Return buffers to the buffer pool.
  if (bitfield_bit32_read(istate, USBDEV_INTR_COMMON_PKT_RECEIVED_BIT)) {
    while (!rx_fifo_empty()) {
      uint32_t rxfifo = abs_mmio_read32(kBase + USBDEV_RXFIFO_REG_OFFSET);
      uint8_t ep =
          (uint8_t)bitfield_field32_read(rxfifo, USBDEV_RXFIFO_EP_FIELD);
      uint32_t setup = bitfield_bit32_read(rxfifo, USBDEV_RXFIFO_SETUP_BIT);
      uint32_t size = bitfield_field32_read(rxfifo, USBDEV_RXFIFO_SIZE_FIELD);
      uint8_t buffer =
          (uint8_t)bitfield_field32_read(rxfifo, USBDEV_RXFIFO_BUFFER_FIELD);
      usb_ep_info_t *endpoint = out_endpoints + ep;

      if (endpoint->handler == NULL) {
        buffer_pool_put(buffer);
        continue;
      }
      if (setup) {
        // Send SETUP_DATA directly to the endpoint handler.
        copy_from_buffer(buffer, (char *)&setup_data, sizeof(setup_data));
        buffer_pool_put(buffer);
        endpoint->handler(endpoint->user_ctx, ep, kUsbTransactionFlagsSetupData,
                          &setup_data);
        continue;
      }
      // TODO(cfrantz): if size>transfer.len, then we should flags some sort
      // of error on this transfer.
      size_t chunk =
          size < endpoint->transfer.len ? size : endpoint->transfer.len;
      copy_from_buffer(buffer, endpoint->transfer.data, chunk);
      buffer_pool_put(buffer);
      endpoint->transfer.data += chunk;
      endpoint->transfer.len -= chunk;
      endpoint->transfer.bytes_transfered += chunk;
      if (endpoint->transfer.len == 0 || chunk < endpoint->size) {
        if (endpoint->transfer.flags & kUsbTransactionFlagsControl) {
          // If this is a control transfer, we need to turn around the packet
          // with a zero-byte IN.
          usb_ep_transfer(kUsbDirIn | ep, NULL, 0,
                          kUsbTransactionFlagsControlAck);
        } else {
          // Complete the transfer.
          if (endpoint->transfer.flags & kUsbTransactionFlagsControlAck) {
            endpoint->transfer.flags = 0;
            endpoint = in_endpoints + ep;
          }
          endpoint->transfer.flags |= kUsbTransactionFlagsDone;
          endpoint->handler(endpoint->user_ctx, ep, endpoint->transfer.flags,
                            &endpoint->transfer.bytes_transfered);
        }
      }
    }
  }

  // Handle a USB reset condition.  Reclaim all pending buffers, zero out all
  // pending transfers and call all endpoint calbacks with the reset flag.
  if (bitfield_bit32_read(istate, USBDEV_INTR_COMMON_LINK_RESET_BIT)) {
    // For each endpoint, cancel any existing transfers.
    for (uint8_t ep = 0; ep < USBDEV_PARAM_N_ENDPOINTS; ++ep) {
      uint32_t reg = abs_mmio_read32(kBase + USBDEV_CONFIGIN_0_REG_OFFSET +
                                     ep * sizeof(uint32_t));
      bool pending = bitfield_bit32_read(reg, USBDEV_CONFIGIN_0_PEND_0_BIT);
      uint8_t buffer =
          (uint8_t)bitfield_field32_read(reg, USBDEV_CONFIGIN_0_BUFFER_0_FIELD);
      if (pending) {
        buffer_pool_put(buffer);
        abs_mmio_write32(
            kBase + USBDEV_CONFIGIN_0_REG_OFFSET + ep * sizeof(uint32_t),
            1 << USBDEV_CONFIGIN_0_PEND_0_BIT);
      }
      usb_ep_info_t *endpoint = in_endpoints + ep;
      if (endpoint->handler) {
        endpoint->transfer.flags = 0;
        endpoint->transfer.data = NULL;
        endpoint->transfer.len = 0;
        // Send a reset notifiy for direction IN, but non-control endpoints.
        // We'll send the reset notify for control endpoints with the OUT
        // endpoints.
        if ((endpoint->flags & kUsbEpFlagsControl) == 0) {
          endpoint->handler(endpoint->user_ctx, kUsbDirIn | ep,
                            kUsbTransactionFlagsReset, NULL);
        }
      }
      endpoint = out_endpoints + ep;
      if (endpoint->handler) {
        endpoint->transfer.flags = 0;
        endpoint->transfer.data = NULL;
        endpoint->transfer.len = 0;
        endpoint->handler(endpoint->user_ctx, ep, kUsbTransactionFlagsReset,
                          NULL);
      }
    }
  }

  // Ack interrupt bits.
  abs_mmio_write32(kBase + USBDEV_INTR_STATE_REG_OFFSET, istate);
}

void usb_set_address(uint8_t device_address) {
  uint32_t val = abs_mmio_read32(kBase + USBDEV_USBCTRL_REG_OFFSET);
  val = bitfield_field32_write(val, USBDEV_USBCTRL_DEVICE_ADDRESS_FIELD,
                               device_address);
  abs_mmio_write32(kBase + USBDEV_USBCTRL_REG_OFFSET, val);
}

void usb_enable(bool en) {
  uint32_t val = abs_mmio_read32(kBase + USBDEV_USBCTRL_REG_OFFSET);
  val = bitfield_bit32_write(val, USBDEV_USBCTRL_ENABLE_BIT, en);
  abs_mmio_write32(kBase + USBDEV_USBCTRL_REG_OFFSET, val);
}

void usb_init(void) {
  usb_phy_init();
  buffer_pool_init();
  fill_fifos();
}
