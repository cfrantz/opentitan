// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "sw/device/lib/base/memory.h"
#include "sw/device/lib/base/abs_mmio.h"
#include "sw/device/lib/base/status.h"
#include "sw/device/lib/dif/dif_aon_timer.h"
#include "sw/device/lib/dif/dif_pwrmgr.h"
#include "sw/device/lib/runtime/log.h"
#include "sw/device/lib/testing/aon_timer_testutils.h"
#include "sw/device/lib/testing/pwrmgr_testutils.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"
#include "sw/device/silicon_creator/lib/drivers/retention_sram.h"
#include "sw/device/silicon_creator/lib/drivers/rstmgr.h"

#include "hw/top_earlgrey/sw/autogen/top_earlgrey.h"

#include "clkmgr_regs.h"
#include "pinmux_regs.h"
#include "pwrmgr_regs.h"
#include "sram_ctrl_regs.h"
#include "rstmgr_regs.h"
#include "aon_timer_regs.h"


OTTF_DEFINE_TEST_CONFIG();

typedef enum regwen {
  kRegwenUnknown = 0,
  kRegwenClkmgrJitter,
  kRegwenPinmux,
  kRegwenPwrmgrResetEn,
  kRegwenRetRamSramCtrl,
  kRegwenRstmgrAlert,
  kRegwenAonTimerWdog,
} regwen_t;

#ifndef REGWEN
#define REGWEN kRegwenClkmgrJitter
#endif

status_t lock_regwen(regwen_t which) {
  uint32_t addr, val;
  switch(which) {
  case kRegwenClkmgrJitter:
    addr = TOP_EARLGREY_CLKMGR_AON_BASE_ADDR + CLKMGR_JITTER_REGWEN_REG_OFFSET;
    val = abs_mmio_read32(addr);
    LOG_INFO("CLKMGR_JITTER_REGWEN = %d%s", val, val ? " -> 0" : "");
    abs_mmio_write32(addr, 0);
    break;
  case kRegwenPinmux:
    addr = TOP_EARLGREY_PINMUX_AON_BASE_ADDR + 0;
    break;
  case kRegwenPwrmgrResetEn:
    addr = TOP_EARLGREY_PWRMGR_AON_BASE_ADDR + PWRMGR_RESET_EN_REGWEN_REG_OFFSET;
    val = abs_mmio_read32(addr);
    LOG_INFO("PWRMGR_RESET_EN_REGWEN = %d%s", val, val ? " -> 0" : "");
    abs_mmio_write32(addr, 0);
    break;
  case kRegwenRetRamSramCtrl:
    addr = TOP_EARLGREY_SRAM_CTRL_RET_AON_REGS_BASE_ADDR + SRAM_CTRL_CTRL_REGWEN_REG_OFFSET;
    val = abs_mmio_read32(addr);
    LOG_INFO("SRAM_CTRL_CTRL_REGWEN = %d%s", val, val ? " -> 0" : "");
    abs_mmio_write32(addr, 0);
    break;
  case kRegwenRstmgrAlert:
    addr = TOP_EARLGREY_RSTMGR_AON_BASE_ADDR + RSTMGR_ALERT_REGWEN_REG_OFFSET;
    val = abs_mmio_read32(addr);
    LOG_INFO("RSTMGR_ALERT_REGWEN = %d%s", val, val ? " -> 0" : "");
    abs_mmio_write32(addr, 0);
    break;
  case kRegwenAonTimerWdog:
    addr = TOP_EARLGREY_AON_TIMER_AON_BASE_ADDR + AON_TIMER_WDOG_REGWEN_REG_OFFSET;
    val = abs_mmio_read32(addr);
    LOG_INFO("AON_TIMER_WDOG_REGWEN = %d%s", val, val ? " -> 0" : "");
    abs_mmio_write32(addr, 0);
    break;
  default:
    return UNKNOWN();
  }
  return OK_STATUS();
}

status_t lock_and_boot_test(void) {
  // Variables of type `retention_sram_t` are static to reduce stack usage.
  retention_sram_t *ret = retention_sram_get();
  uint32_t reset_reasons = ret->creator.reset_reasons;

  // Verify that reset_reasons reports POR.
  if (bitfield_bit32_read(reset_reasons, kRstmgrReasonPowerOn)) {
    // This branch runs after the POR after initializing the testing environment

    TRY(lock_regwen(REGWEN));

    // Initialize pwrmgr
    dif_pwrmgr_t pwrmgr;
    CHECK_DIF_OK(dif_pwrmgr_init(
        mmio_region_from_addr(TOP_EARLGREY_PWRMGR_AON_BASE_ADDR), &pwrmgr));

    // Initialize aon timer
    // Issue a wakeup signal in ~1ms through the AON timer.
    //
    // At 200kHz, threshold of 200 is equal to 1ms.
    // Adjust the threshold for Verilator since it runs on different clock
    // frequencies.
    uint64_t wakeup_threshold = kDeviceType == kDeviceSimVerilator ? 300 : 200;

    dif_aon_timer_t aon_timer;
    CHECK_DIF_OK(dif_aon_timer_init(
        mmio_region_from_addr(TOP_EARLGREY_AON_TIMER_AON_BASE_ADDR),
        &aon_timer));
    CHECK_STATUS_OK(
        aon_timer_testutils_wakeup_config(&aon_timer, wakeup_threshold));

    // Enter low-power
    static_assert(kDifPwrmgrWakeupRequestSourceFive ==
                      (1u << PWRMGR_PARAM_AON_TIMER_AON_WKUP_REQ_IDX),
                  "Layout of WAKE_INFO register changed.");
    CHECK_STATUS_OK(pwrmgr_testutils_enable_low_power(
        &pwrmgr, kDifPwrmgrWakeupRequestSourceFive, 0));
    LOG_INFO("Issue WFI to enter sleep");
    wait_for_interrupt();  // Enter low-power
    // We should never get here.
    return INTERNAL();
  } else if (bitfield_bit32_read(reset_reasons, kRstmgrReasonLowPowerExit)) {
    LOG_INFO("Woke up from low power exit");
    TRY(lock_regwen(REGWEN));
    return OK_STATUS();
  } else {
    LOG_INFO("Resuming from unknown reset: %08x", reset_reasons);
    return UNKNOWN();
  }
}

bool test_main(void) {
  status_t result = OK_STATUS();
  EXECUTE_TEST(result, lock_and_boot_test);
  return status_ok(result);
}
