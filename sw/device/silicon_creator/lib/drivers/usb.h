// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#ifndef OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_DRIVERS_USB_H_
#define OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_DRIVERS_USB_H_

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "sw/device/silicon_creator/lib/drivers/stdusb.h"
#include "sw/device/silicon_creator/lib/error.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Flags for endpoint configuration
 */
typedef enum usb_dir {
  /** Endpoint is an IN endpoint */
  kUsbDirIn = 0x80,
  /** Endpoint is a OUT endpoint */
  kUsbDirOut = 0,
  /** Endpoint number mask */
  kEpNumMask = 0xf,
} usb_dir_t;

typedef enum usb_ep_flags {
  /** Endpoint is a BULK endpoint */
  kUsbEpFlagsBulk = 0,
  /** Endpoint is a CONTROL endpoint */
  kUsbEpFlagsControl = 1,
} usb_ep_flags_t;

/**
 * Flags for managing usb transfers
 */
typedef enum usb_transaction_flags {
  /** Transfer needs to terminate with a short or zero-length packet. */
  kUsbTransactionFlagsShortIn = 1,
  /**
   * Transfer is a control transfer: requires a zero-length packet in the
   * opposite direction of the transfer to complete
   */
  kUsbTransactionFlagsControl = 2,
  /**
   * Request an IN transaction.  This is an alias for kUsbDirIn to allow
   * protocol code that might hide the endpoint address from the
   * implementation to request an IN transaction.
   */
  kUsbTransactionFlagsIn = 0x80,

  /**
   * Transfer is the zero-length control transfer status packet.
   */
  kUsbTransactionFlagsControlAck = 0x1000,
  /**
   * Indicates a SETUP_DATA packet; the data argument of the callback points to
   * a usb_setup_data_t.
   */
  kUsbTransactionFlagsSetupData = 0x2000,
  /**
   * Transfer is finished; the data argument of the callback points to a size_t
   * indicating the number of bytes transferred.
   */
  kUsbTransactionFlagsDone = 0x4000,
  /** USB device was reset */
  kUsbTransactionFlagsReset = 0x8000,
} usb_transaction_flags_t;

/**
 * Function pointer type for an endpoint handler.
 *
 * @param ctx A pointer to the context object supplied during endpoint
 *            initialization.
 * @param ep The endpoint address (including the direction flag).
 * @param flags The usb transfer flags for this callback.
 * @param data A pointer to data relevant to this callback (see the flags).
 */
typedef void (*handler_t)(void *ctx, uint8_t ep, usb_transaction_flags_t flags,
                          void *data);

/**
 * An internal driver struct to manage endpoint transfers.
 */
typedef struct usb_transfer {
  /** Pointer to data to transfer. */
  char *data;
  /** Length of data remaining to transfer. */
  size_t len;
  /** Number of bytes actually transferred. */
  size_t bytes_transfered;
  /** Flags associated with this transfer. */
  usb_transaction_flags_t flags;
} usb_transfer_t;

/**
 * An internal driver struct to manage each endpoint.
 */
typedef struct usb_ep_info {
  /** Endpoint flags (e.g. control EP or other properties) */
  usb_ep_flags_t flags;
  /** The size of this endpoint. */
  uint16_t size;
  /** Any active transfer on this endpoint. */
  usb_transfer_t transfer;
  /** A handler to call for events on this endpoint. */
  handler_t handler;
  /** The user supplied context to pass to the handler. */
  void *user_ctx;
} usb_ep_info_t;

/**
 * Initialize the USB stack.
 *
 */
void usb_init(void);

/**
 * Poll the USB device, driver transfers to completion and call endpoint
 * callbacks.
 *
 */
void usb_poll(void);

/**
 * Enable USB.
 */
void usb_enable(bool en);

/**
 * Set the USB address.
 */
void usb_set_address(uint8_t device_address);

/**
 * Initialize an USB endpoint.
 *
 * @param ep The endpoint address (including the direction flag).
 * @param type The endpoint type (Bulk, Control).
 * @param size The endpoint size.
 * @param handler A handler to call when transactions complete on the endpoint.
 * @param user_ctx A context pointer to pass to the handler.
 * @return Error code.
 */
rom_error_t usb_ep_init(uint8_t ep, usb_ep_flags_t type, uint16_t size,
                        handler_t handler, void *user_ctx);

/**
 * Stall or un-stall an endpoint.
 *
 * @param ep The endpoint address (including the direction flag).
 * @param enable Whether to enable (true) or clear (false) the stall condition.
 * @return Error code.
 */
rom_error_t usb_ep_stall(uint8_t ep, bool enable);

/**
 * Return whether an endpoint is stalled.
 *
 * @param ep The endpoint address (including the direction flag).
 * @param stalled[out] Whether the endpoint is stalled.
 * @return Error code.
 */
rom_error_t usb_ep_stalled(uint8_t ep, bool *stalled);

/**
 * Start a transfer on an endpoint.
 *
 *
 * @param ep The endpoint address (including the direction flag).
 *           Note: The other APIs (init, stall, stalled) do not require the
 *           direction flag when operating on a control endpoint.  However,
 *           since control endpoints may transfer data either in or out, you
 *           must include the direction flag here.
 * @param data The buffer to send or receive into.
 * @param len The length of the buffer.
 * @param flags The direction or other attributes assocated with the transfer.
 * @return Error code.
 */
rom_error_t usb_ep_transfer(uint8_t ep, void *data, size_t len,
                            usb_transaction_flags_t flags);

#ifdef __cplusplus
}
#endif

#endif  // OPENTITAN_SW_DEVICE_SILICON_CREATOR_LIB_DRIVERS_USB_H_
