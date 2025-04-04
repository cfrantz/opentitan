// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/testing/usb_testutils_controlep.h"

#include "sw/device/lib/base/macros.h"
#include "sw/device/lib/dif/dif_usbdev.h"
#include "sw/device/lib/runtime/ibex.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/usb_testutils.h"

#define MODULE_ID MAKE_MODULE_ID('u', 't', 'c')

// Device descriptor
static const uint8_t kDevDscr[] = {
    18,    // bLength
    1,     // bDescriptorType
    0x00,  // bcdUSB[0]
    0x02,  // bcdUSB[1]
    0x00,  // bDeviceClass (defined at interface level)
    0x00,  // bDeviceSubClass
    0x00,  // bDeviceProtocol
    64,    // bMaxPacketSize0

    0xd1,  // idVendor[0] 0x18d1 Google Inc.
    0x18,  // idVendor[1]
    0x3a,  // idProduct[0] lowRISC generic FS USB
    0x50,  // idProduct[1] (allocated by Google)

    0,    // bcdDevice[0]
    0x1,  // bcdDevice[1]
    0,    // iManufacturer
    0,    // iProduct
    0,    // iSerialNumber
    1     // bNumConfigurations
};

// SETUP requests
typedef enum usb_setup_req {
  kUsbSetupReqGetStatus = 0,
  kUsbSetupReqClearFeature = 1,
  kUsbSetupReqSetFeature = 3,
  kUsbSetupReqSetAddress = 5,
  kUsbSetupReqGetDescriptor = 6,
  kUsbSetupReqSetDescriptor = 7,
  kUsbSetupReqGetConfiguration = 8,
  kUsbSetupReqSetConfiguration = 9,
  kUsbSetupReqGetInterface = 10,
  kUsbSetupReqSetInterface = 11,
  kUsbSetupReqSynchFrame = 12
} usb_setup_req_t;

// Vendor-specific requests defined by our device/test framework
typedef enum vendor_setup_req {
  kVendorSetupReqTestConfig = 0x7C,
  kVendorSetupReqTestStatus = 0x7E
} vendor_setup_req_t;

typedef enum usb_req_type {  // bmRequestType
  kUsbReqTypeRecipientMask = 0x1f,
  kUsbReqTypeDevice = 0,
  kUsbReqTypeInterface = 1,
  kUsbReqTypeEndpoint = 2,
  kUsbReqTypeOther = 3,
  kUsbReqTypeTypeMask = 0x60,
  kUsbReqTypeStandard = 0,
  kUsbReqTypeClass = 0x20,
  kUsbReqTypeVendor = 0x40,
  kUsbReqTypeReserved = 0x60,
  kUsbReqTypeDirMask = 0x80,
  kUsbReqTypeDirH2D = 0x00,
  kUsbReqTypeDirD2H = 0x80,
} usb_req_type_t;

typedef enum usb_desc_type {  // Descriptor type (wValue hi)
  kUsbDescTypeDevice = 1,
  kUsbDescTypeConfiguration,
  kUsbDescTypeString,
  kUsbDescTypeInterface,
  kUsbDescTypeEndpoint,
  kUsbDescTypeDeviceQualifier,
  kUsbDescTypeOtherSpeedConfiguration,
  kUsbDescTypeInterfacePower,
} usb_desc_type_t;

typedef enum usb_feature_req {
  kUsbFeatureEndpointHalt = 0,        // recipient is endpoint
  kUsbFeatureDeviceRemoteWakeup = 1,  // recipient is device
  kUsbFeatureTestMode = 2,            // recipient is device
  kUsbFeatureBHnpEnable = 3,          // recipient is device only if OTG
  kUsbFeatureAHnpSupport = 4,         // recipient is device only if OTG
  kUsbFeatureAAltHnpSupport = 5       // recipient is device only if OTG
} usb_feature_req_t;

typedef enum usb_status {
  kUsbStatusSelfPowered = 1,  // Device status request
  kUsbStatusRemWake = 2,      // Device status request
  kUsbStatusHalted = 1        // Endpoint status request
} usb_status_t;

static usb_testutils_ctstate_t setup_req(usb_testutils_controlep_ctx_t *ctctx,
                                         usb_testutils_ctx_t *ctx,
                                         uint8_t bmRequestType,
                                         uint8_t bRequest, uint16_t wValue,
                                         uint16_t wIndex, uint16_t wLength) {
  size_t len;
  uint32_t stat;
  int zero, type;
  size_t bytes_written;
  // Endpoint for SetFeature/ClearFeature/GetStatus requests
  dif_usbdev_endpoint_id_t endpoint = {
      .number = (uint8_t)wIndex,
      .direction = ((bmRequestType & 0x80U) != 0U),
  };
  dif_usbdev_buffer_t buffer;
  CHECK_DIF_OK(dif_usbdev_buffer_request(ctx->dev, ctx->buffer_pool, &buffer));
  switch (bRequest) {
    case kUsbSetupReqGetDescriptor:
      if ((wValue & 0xff00) == 0x100) {
        // Device descriptor
        len = sizeof(kDevDscr);
        if (wLength < len) {
          len = wLength;
        }
        CHECK_DIF_OK(dif_usbdev_buffer_write(ctx->dev, &buffer, kDevDscr, len,
                                             &bytes_written));
        CHECK(bytes_written == len);
        CHECK_DIF_OK(dif_usbdev_send(ctx->dev, ctctx->ep, &buffer));
        return kUsbTestutilsCtWaitIn;
      } else if ((wValue & 0xff00) == 0x200) {
        usb_testutils_xfr_flags_t flags = kUsbTestutilsXfrDoubleBuffered;

        // Configuration descriptor
        len = ctctx->cfg_dscr_len;
        if (wLength < len) {
          len = wLength;
        } else if (wLength > len) {
          // Since we're not sending as much as requested, we may need to use
          // a Zero Length Packet to mark the end of the data stage
          flags |= kUsbTestutilsXfrEmployZLP;
        }

        if (len >= USBDEV_MAX_PACKET_SIZE) {
          CHECK_DIF_OK(
              dif_usbdev_buffer_return(ctx->dev, ctx->buffer_pool, &buffer));

          if (UNWRAP(usb_testutils_transfer_send(ctx, 0U, ctctx->cfg_dscr, len,
                                                 flags)) == false) {
            return kUsbTestutilsCtError;
          }
        } else {
          CHECK_DIF_OK(dif_usbdev_buffer_write(
              ctx->dev, &buffer, ctctx->cfg_dscr, len, &bytes_written));
          CHECK_DIF_OK(dif_usbdev_send(ctx->dev, ctctx->ep, &buffer));
        }
        return kUsbTestutilsCtWaitIn;
      }
      return kUsbTestutilsCtError;  // unknown

    case kUsbSetupReqSetAddress:
      TRC_S("SA");
      ctctx->new_dev = (uint8_t)(wValue & 0x7fU);
      // send zero length packet for status phase
      CHECK_DIF_OK(dif_usbdev_send(ctx->dev, ctctx->ep, &buffer));
      return kUsbTestutilsCtAddrStatIn;

    case kUsbSetupReqSetConfiguration:
      TRC_S("SC");
      // only ever expect this to be 1 since there is one config descriptor
      ctctx->new_config = (uint8_t)wValue;
      // send zero length packet for status phase
      CHECK_DIF_OK(dif_usbdev_send(ctx->dev, ctctx->ep, &buffer));
      return kUsbTestutilsCtCfgStatIn;

    case kUsbSetupReqGetConfiguration:
      len = sizeof(ctctx->usb_config);
      if (wLength < len) {
        len = wLength;
      }
      // return the value that was set
      CHECK_DIF_OK(dif_usbdev_buffer_write(
          ctx->dev, &buffer, &ctctx->usb_config, len, &bytes_written));
      CHECK_DIF_OK(dif_usbdev_send(ctx->dev, ctctx->ep, &buffer));
      return kUsbTestutilsCtWaitIn;

    case kUsbSetupReqSetFeature:
      if (wValue == kUsbFeatureEndpointHalt) {
        CHECK_DIF_OK(dif_usbdev_endpoint_stall_enable(ctx->dev, endpoint,
                                                      kDifToggleEnabled));
        // send zero length packet for status phase
        CHECK_DIF_OK(dif_usbdev_send(ctx->dev, ctctx->ep, &buffer));
        return kUsbTestutilsCtStatIn;
      }
      return kUsbTestutilsCtError;  // unknown

    case kUsbSetupReqClearFeature:
      if (wValue == kUsbFeatureEndpointHalt) {
        CHECK_DIF_OK(dif_usbdev_endpoint_stall_enable(ctx->dev, endpoint,
                                                      kDifToggleDisabled));
        // Clearing the Halt feature on an endpoint that is using Data Toggling
        // also requires us to clear the Data Toggle for that endpoint
        CHECK_DIF_OK(dif_usbdev_clear_data_toggle(ctx->dev, endpoint.number));
        // send zero length packet for status phase
        CHECK_DIF_OK(dif_usbdev_send(ctx->dev, ctctx->ep, &buffer));
        return kUsbTestutilsCtStatIn;
      }
      // We must return a Request Error (STALL in response to Status stage)
      return kUsbTestutilsCtError;  // unknown

    case kUsbSetupReqGetStatus:
      len = 2;
      type = bmRequestType & kUsbReqTypeRecipientMask;
      if (type == kUsbReqTypeDevice) {
        stat = kUsbStatusSelfPowered;
      } else if (type == kUsbReqTypeEndpoint) {
        bool halted;
        CHECK_DIF_OK(
            dif_usbdev_endpoint_stall_get(ctx->dev, endpoint, &halted));
        stat = halted ? kUsbStatusHalted : 0;
      } else {
        stat = 0;
      }
      if (wLength < len) {
        len = wLength;
      }
      // return the value that was set
      CHECK_DIF_OK(dif_usbdev_buffer_write(ctx->dev, &buffer, (uint8_t *)&stat,
                                           len, &bytes_written));
      CHECK_DIF_OK(dif_usbdev_send(ctx->dev, ctctx->ep, &buffer));
      return kUsbTestutilsCtWaitIn;

    case kUsbSetupReqSetInterface:
      // Don't support alternate interfaces, so just ignore
      // send zero length packet for status phase
      CHECK_DIF_OK(dif_usbdev_send(ctx->dev, ctctx->ep, &buffer));
      return kUsbTestutilsCtStatIn;

    case kUsbSetupReqGetInterface:
      zero = 0;
      len = 1;
      if (wLength < len) {
        len = wLength;
      }
      // Don't support interface, so return zero
      CHECK_DIF_OK(dif_usbdev_buffer_write(ctx->dev, &buffer, (uint8_t *)&zero,
                                           len, &bytes_written));
      CHECK_DIF_OK(dif_usbdev_send(ctx->dev, ctctx->ep, &buffer));
      return kUsbTestutilsCtWaitIn;

    case kUsbSetupReqSynchFrame:
      zero = 0;
      len = 2;
      if (wLength < len) {
        len = wLength;
      }
      // Don't support synch_frame so return zero
      CHECK_DIF_OK(dif_usbdev_buffer_write(ctx->dev, &buffer, (uint8_t *)&zero,
                                           len, &bytes_written));
      CHECK_DIF_OK(dif_usbdev_send(ctx->dev, ctctx->ep, &buffer));
      return kUsbTestutilsCtWaitIn;

    default:
      // We implement a couple of bespoke, vendor-defined Setup requests to
      // allow the DPI model to access the test configuration (Control Read) and
      // to report the test status (Control Write)
      if ((bmRequestType & kUsbReqTypeTypeMask) == kUsbReqTypeVendor &&
          ctctx->test_dscr) {
        switch ((vendor_setup_req_t)bRequest) {
          case kVendorSetupReqTestConfig: {
            TRC_S("TC");
            // Test config descriptor
            len = ctctx->test_dscr_len;
            if (wLength < len) {
              len = wLength;
            }
            CHECK_DIF_OK(dif_usbdev_buffer_write(
                ctx->dev, &buffer, ctctx->test_dscr, len, &bytes_written));
            CHECK_DIF_OK(dif_usbdev_send(ctx->dev, ctctx->ep, &buffer));
            return kUsbTestutilsCtWaitIn;
          } break;
          case kVendorSetupReqTestStatus: {
            // TODO - pass the received test status to the OTTF directly?
          } break;
        }
      }
      return kUsbTestutilsCtError;
  }
  return kUsbTestutilsCtError;
}

static status_t ctrl_tx_done(void *ctctx_v, usb_testutils_xfr_result_t result) {
  usb_testutils_controlep_ctx_t *ctctx =
      (usb_testutils_controlep_ctx_t *)ctctx_v;
  usb_testutils_ctx_t *ctx = ctctx->ctx;
  TRC_C('A' + ctctx->ctrlstate);
  switch (ctctx->ctrlstate) {
    case kUsbTestutilsCtAddrStatIn:
      // Now the Status was sent on Endpoint Zero, the device can switch to new
      // Device Address
      TRY(dif_usbdev_address_set(ctx->dev, ctctx->new_dev));
      TRC_I(ctctx->new_dev, 8);
      ctctx->ctrlstate = kUsbTestutilsCtIdle;
      // We now have a device address on the USB
      ctctx->device_state = kUsbTestutilsDeviceAddressed;
      return OK_STATUS();
    case kUsbTestutilsCtCfgStatIn:
      // Now the Status was sent on Endpoint Zero, the new configuration has
      // been (de)selected.
      ctctx->usb_config = ctctx->new_config;
      ctctx->ctrlstate = kUsbTestutilsCtIdle;
      if (ctctx->new_config) {
        ctctx->device_state = kUsbTestutilsDeviceConfigured;
      } else {
        // Device deconfigured
        ctctx->device_state = kUsbTestutilsDeviceAddressed;
      }
      return OK_STATUS();
    case kUsbTestutilsCtStatIn:
      ctctx->ctrlstate = kUsbTestutilsCtIdle;
      return OK_STATUS();
    case kUsbTestutilsCtWaitIn:
      ctctx->ctrlstate = kUsbTestutilsCtStatOut;
      return OK_STATUS();

    default:
      break;
  }
  TRC_S("USB: unexpected IN ");
  TRC_I((ctctx->ctrlstate << 24), 32);
  return OK_STATUS();
}

static status_t ctrl_rx(void *ctctx_v, dif_usbdev_rx_packet_info_t packet_info,
                        dif_usbdev_buffer_t buffer) {
  usb_testutils_controlep_ctx_t *ctctx =
      (usb_testutils_controlep_ctx_t *)ctctx_v;
  usb_testutils_ctx_t *ctx = ctctx->ctx;
  TRY(dif_usbdev_endpoint_out_enable(ctx->dev, /*endpoint=*/0,
                                     kDifToggleEnabled));

  TRC_C('0' + ctctx->ctrlstate);
  size_t bytes_written;
  // TODO: Should check for canceled IN transactions due to receiving a SETUP
  // packet.
  switch (ctctx->ctrlstate) {
    case kUsbTestutilsCtIdle:
      // Waiting to be set up
      if (packet_info.is_setup && (packet_info.length == 8)) {
        alignas(uint32_t) uint8_t bp[8];
        TRY(dif_usbdev_buffer_read(ctx->dev, ctx->buffer_pool, &buffer, bp,
                                   sizeof(bp), &bytes_written));
        uint8_t bmRequestType = bp[0];
        uint8_t bRequest = bp[1];
        uint16_t wValue = (uint16_t)((bp[3] << 8) | bp[2]);
        uint16_t wIndex = (uint16_t)((bp[5] << 8) | bp[4]);
        uint16_t wLength = (uint16_t)((bp[7] << 8) | bp[6]);
        TRC_C('0' + bRequest);

        ctctx->ctrlstate = setup_req(ctctx, ctx, bmRequestType, bRequest,
                                     wValue, wIndex, wLength);
        if (ctctx->ctrlstate != kUsbTestutilsCtError) {
          return OK_STATUS();
        }

        TRC_C(':');
        for (int i = 0; i < packet_info.length; i++) {
          TRC_I(bp[i], 8);
        }
      }
      break;

    case kUsbTestutilsCtStatOut:
      // Have sent some data, waiting STATUS stage
      if (!packet_info.is_setup && (packet_info.length == 0)) {
        TRY(dif_usbdev_buffer_return(ctx->dev, ctx->buffer_pool, &buffer));
        ctctx->ctrlstate = kUsbTestutilsCtIdle;
        return OK_STATUS();
      }
      // anything else is unexpected
      break;

    default:
      // Error
      break;
  }
  dif_usbdev_endpoint_id_t endpoint = {
      .number = 0,
      .direction = USBDEV_ENDPOINT_DIR_IN,
  };
  // Enable responding with STALL. Will be cleared by the HW upon next SETUP.
  TRY(dif_usbdev_endpoint_stall_enable(ctx->dev, endpoint, kDifToggleEnabled));
  endpoint.direction = USBDEV_ENDPOINT_DIR_OUT;
  TRY(dif_usbdev_endpoint_stall_enable(ctx->dev, endpoint, kDifToggleEnabled));

  TRC_S("USB: unCT ");
  TRC_I((ctctx->ctrlstate << 24) | ((uint32_t)packet_info.is_setup << 16) |
            packet_info.length,
        32);
  if (buffer.type != kDifUsbdevBufferTypeStale) {
    // Return the unused buffer.
    TRY(dif_usbdev_buffer_return(ctx->dev, ctx->buffer_pool, &buffer));
  }
  ctctx->ctrlstate = kUsbTestutilsCtIdle;
  return OK_STATUS();
}

// Callback for the USB link reset
static status_t ctrl_reset(void *ctctx_v) {
  usb_testutils_controlep_ctx_t *ctctx =
      (usb_testutils_controlep_ctx_t *)ctctx_v;
  ctctx->ctrlstate = kUsbTestutilsCtIdle;
  // We have lost any device address that we were assigned; the device has
  // cleared its own copy of the device address automatically.
  ctctx->device_state = kUsbTestutilsDeviceDefault;
  return OK_STATUS();
}

status_t usb_testutils_controlep_init(usb_testutils_controlep_ctx_t *ctctx,
                                      usb_testutils_ctx_t *ctx, uint8_t ep,
                                      const uint8_t *cfg_dscr,
                                      size_t cfg_dscr_len,
                                      const uint8_t *test_dscr,
                                      size_t test_dscr_len) {
  ctctx->ctx = ctx;
  TRY(usb_testutils_endpoint_setup(
      ctx, ep, kUsbTransferTypeControl, kUsbTransferTypeControl,
      kUsbdevOutMessage, ctctx, ctrl_tx_done, ctrl_rx, NULL, ctrl_reset));
  ctctx->ep = ep;
  ctctx->ctrlstate = kUsbTestutilsCtIdle;
  ctctx->cfg_dscr = cfg_dscr;
  ctctx->cfg_dscr_len = cfg_dscr_len;
  ctctx->test_dscr = test_dscr;
  ctctx->test_dscr_len = test_dscr_len;
  ctctx->device_state = kUsbTestutilsDeviceDefault;

  // Indicate the device presence, at which point we can expect to start
  // receiving control transfers from the host
  TRY(dif_usbdev_interface_enable(ctx->dev, kDifToggleEnabled));

  return OK_STATUS();
}

// Proceed only when the device has been configured; this allows host-side
// software to establish communication.
status_t usb_testutils_controlep_config_wait(
    usb_testutils_controlep_ctx_t *ctctx, usb_testutils_ctx_t *ctx) {
  // In simulation the DPI (host) is very responsive, and it will take only
  // a handful of bus frames to set the configuration; importantly we want
  // regression simulations to terminate sooner rather than later if there
  // is a gross connectivity failure.
  uint32_t timeout_usecs = 8 * 1000;  // 8ms = 8 x 1ms bus frames
  switch (kDeviceType) {
    case kDeviceSimDV:
      break;
    case kDeviceSimVerilator: {
      // The Verilator simulation runs the CPU and the USB DPI model on the same
      // clock, and the USB bus frame is 1ms (= 48,000 clock cycles), so we
      // simply want to set the timeout in terms of clock cycles.
      uint64_t clk_cycles = 48 * timeout_usecs;
      timeout_usecs =
          (uint32_t)udiv64_slow(clk_cycles * 1000000, kClockFreqCpuHz, NULL);
    } break;
    default:
      // With an FGPA build the host software will respond more slowly and there
      // may even be a requirement for user intervention such as cabling.
      timeout_usecs = 30 * 1000000;
      break;
  }
  ibex_timeout_t timeout = ibex_timeout_init(timeout_usecs);
  while (ctctx->device_state != kUsbTestutilsDeviceConfigured &&
         !ibex_timeout_check(&timeout)) {
    TRY(usb_testutils_poll(ctx));
  }
  if (ctctx->device_state != kUsbTestutilsDeviceConfigured) {
    // Don't wait indefinitely because there may be no usable connection.
    return UNAVAILABLE();
  }
  return OK_STATUS();
}
