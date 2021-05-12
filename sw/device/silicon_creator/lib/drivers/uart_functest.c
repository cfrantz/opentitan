// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <stdbool.h>
#include <stdint.h>

#include "sw/device/lib/arch/device.h"
#include "sw/device/lib/base/mmio.h"
#include "sw/device/lib/runtime/print.h"
#include "sw/device/lib/testing/test_main.h"
#include "sw/device/silicon_creator/lib/drivers/uart.h"

#include "hw/top_earlgrey/sw/autogen/top_earlgrey.h"

const test_config_t kTestConfig = {
    .can_clobber_uart = true,
};

uart_t uart;

bool test_main(void) {
  // Configure UART0 as stdout.
  // TODO(lowrisc/opentitan#6283): Move to constant driver handles.
  uart.base_addr = mmio_region_from_addr(TOP_EARLGREY_UART0_BASE_ADDR);
  uart.baudrate = kUartBaudrate;
  uart.clk_freq_hz = kClockFreqPeripheralHz;
  uart_init(&uart);
  base_set_stdout((buffer_sink_t){
      .data = &uart,
      .sink = uart_sink,
  });

  base_printf("uart functional test!\r\n");
  return true;
}
