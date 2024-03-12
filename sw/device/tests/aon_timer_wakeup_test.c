// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <limits.h>
#include <stdbool.h>
#include <stdint.h>

#include "sw/device/lib/base/mmio.h"
#include "sw/device/lib/dif/dif_aon_timer.h"
#include "sw/device/lib/dif/dif_pwrmgr.h"
// #include "sw/device/lib/dif/dif_rstmgr.h"
#include "sw/device/lib/runtime/irq.h"
#include "sw/device/lib/runtime/log.h"
// #include "sw/device/lib/testing/aon_timer_testutils.h"
#include "sw/device/lib/testing/pwrmgr_testutils.h"
// #include "sw/device/lib/testing/rstmgr_testutils.h"
#include "sw/device/lib/testing/rv_plic_testutils.h"
#include "sw/device/lib/testing/test_framework/check.h"
#include "sw/device/lib/testing/test_framework/ottf_main.h"

#include "hw/top_earlgrey/sw/autogen/top_earlgrey.h"
#include "pwrmgr_regs.h"
#include "rv_core_ibex_regs.h"

#define IDLE_TIME_US 10
#define WKUP_TIME_US 2000
OTTF_DEFINE_TEST_CONFIG();

static dif_pwrmgr_t pwrmgr;
static dif_rv_plic_t plic;
static dif_aon_timer_t aon_timer;

void pwrmgr_cdc_sync(void) {
  // Write the pwrmgr's clock domain sync register and wait for it to clear.
  mmio_region_t pwrmgr =
      mmio_region_from_addr(TOP_EARLGREY_PWRMGR_AON_BASE_ADDR);
  mmio_region_write32(pwrmgr, PWRMGR_CFG_CDC_SYNC_REG_OFFSET, 1);
  while (mmio_region_read32(pwrmgr, PWRMGR_CFG_CDC_SYNC_REG_OFFSET)) {
    /* nothing */
  }
}

void ottf_external_isr(uint32_t *exc_info) {
  bool pending;
  dif_rv_plic_irq_id_t plic_irq_id;
  CHECK_DIF_OK(
      dif_rv_plic_irq_claim(&plic, kTopEarlgreyPlicTargetIbex0, &plic_irq_id));
  CHECK_DIF_OK(dif_aon_timer_irq_is_pending(
      &aon_timer, kDifAonTimerIrqWdogTimerBark, &pending));
  if (pending) {
    CHECK_DIF_OK(dif_aon_timer_irq_acknowledge(&aon_timer,
                                               kDifAonTimerIrqWdogTimerBark));
    CHECK_DIF_OK(dif_aon_timer_watchdog_pet(&aon_timer));
    uint32_t time;
    CHECK_DIF_OK(dif_aon_timer_wakeup_get_count(&aon_timer, &time));
    LOG_INFO("IRQ: bark at t=%u", time);
  }
}

void ottf_external_nmi_handler(uint32_t *exc_info) {
  bool pending;

  pwrmgr_cdc_sync();
  // dif_rv_plic_irq_id_t plic_irq_id;
  // CHECK_DIF_OK(
  //     dif_rv_plic_irq_claim(&plic, kTopEarlgreyPlicTargetIbex0,
  //     &plic_irq_id));
  CHECK_DIF_OK(dif_aon_timer_irq_is_pending(
      &aon_timer, kDifAonTimerIrqWdogTimerBark, &pending));

  // Ack the NMI state.
  mmio_region_t ibex =
      mmio_region_from_addr(TOP_EARLGREY_RV_CORE_IBEX_CFG_BASE_ADDR);
  uint32_t nmi = mmio_region_read32(ibex, RV_CORE_IBEX_NMI_STATE_REG_OFFSET);
  mmio_region_write32(ibex, RV_CORE_IBEX_NMI_STATE_REG_OFFSET, nmi);

  if (pending) {
    CHECK_DIF_OK(dif_aon_timer_irq_acknowledge(&aon_timer,
                                               kDifAonTimerIrqWdogTimerBark));

    uint32_t time;
    CHECK_DIF_OK(dif_aon_timer_watchdog_get_count(&aon_timer, &time));
    LOG_INFO("NMI: bark at t=%u", time);
  }
}

static status_t enter_sleep(void) {
  dif_pwrmgr_domain_config_t pwrmgr_domain_cfg = 0;

  // We want the Watchdog BITE to reset the chip.
  CHECK_DIF_OK(dif_pwrmgr_set_request_sources(&pwrmgr, kDifPwrmgrReqTypeReset,
                                              kDifPwrmgrResetRequestSourceTwo,
                                              kDifToggleEnabled));

  // Normal sleep wakes up from an interrupt, so enable the relevant sources.
  // Enable all the AON interrupts used in this test.
  rv_plic_testutils_irq_range_enable(
      &plic, kTopEarlgreyPlicTargetIbex0,
      kTopEarlgreyPlicIrqIdAonTimerAonWdogTimerBark,
      kTopEarlgreyPlicIrqIdAonTimerAonWdogTimerBark);
  // Enable pwrmgr interrupt.
  // TRY(dif_pwrmgr_irq_set_enabled(&pwrmgr, 0, kDifToggleEnabled));

  // Configure the power domains for normal sleep.
  pwrmgr_domain_cfg = kDifPwrmgrDomainOptionMainPowerInLowPower |
                      kDifPwrmgrDomainOptionUsbClockInActivePower;

  uint32_t aon_freq = (uint32_t)kClockFreqAonHz;
  // Watchdog bark in 1 second.
  // Watchdog bite in 5 seconds.
  TRY(dif_aon_timer_watchdog_start(&aon_timer, aon_freq, aon_freq * 5,
                                   /*pause_in_sleep=*/true,
                                   /*lock=*/false));

  // Aon timer prescaler should create 1ms ticks.
  uint32_t prescaler = 2047;  // aon_freq/1000;
  TRY(dif_aon_timer_wakeup_start(&aon_timer, UINT32_MAX, prescaler));

  uint32_t timer_before, wdog;
  TRY(dif_aon_timer_watchdog_get_count(&aon_timer, &wdog));

  TRY(pwrmgr_testutils_enable_low_power(
      &pwrmgr, kDifPwrmgrWakeupRequestSourceFive, pwrmgr_domain_cfg));

  TRY(dif_aon_timer_wakeup_get_count(&aon_timer, &timer_before));
  LOG_INFO("Going to sleep at timer=%u.", timer_before);
  wait_for_interrupt();

  uint32_t timer_after;
  TRY(dif_aon_timer_wakeup_get_count(&aon_timer, &timer_after));

  LOG_INFO("Woke from sleep at timer=%u. Went to sleep at %u.", timer_after,
           timer_before);

  for (;;) {
    TRY(dif_aon_timer_watchdog_get_count(&aon_timer, &wdog));
    LOG_INFO("Hanging out.  Watchdog count = %u", wdog);
    busy_spin_micros(100000);
  }
  return OK_STATUS();
}

static status_t test_init(void) {
  // Initialize aon timer to use the wdog.
  CHECK_DIF_OK(dif_aon_timer_init(
      mmio_region_from_addr(TOP_EARLGREY_AON_TIMER_AON_BASE_ADDR), &aon_timer));

  TRY(dif_pwrmgr_init(mmio_region_from_addr(TOP_EARLGREY_PWRMGR_AON_BASE_ADDR),
                      &pwrmgr));

  TRY(dif_rv_plic_init(mmio_region_from_addr(TOP_EARLGREY_RV_PLIC_BASE_ADDR),
                       &plic));
  // Enable global and external IRQ at Ibex.
  irq_global_ctrl(true);
  irq_external_ctrl(true);

  // Set IRQ priorities to MAX
  TRY(dif_rv_plic_irq_set_priority(
      &plic, kTopEarlgreyPlicIrqIdAonTimerAonWdogTimerBark,
      kDifRvPlicMaxPriority));
  // Set Ibex IRQ priority threshold level
  TRY(dif_rv_plic_target_set_threshold(&plic, kTopEarlgreyPlicTargetIbex0,
                                       kDifRvPlicMinPriority));
  // Enable IRQs in PLIC
  TRY(dif_rv_plic_irq_set_enabled(
      &plic, kTopEarlgreyPlicIrqIdAonTimerAonWdogTimerBark,
      kTopEarlgreyPlicTargetIbex0, kDifToggleEnabled));

  TRY(dif_pwrmgr_set_request_sources(
      &pwrmgr, kDifPwrmgrReqTypeReset,
      kTopEarlgreyPowerManagerResetRequestsAonTimerAonAonTimerRstReq,
      kDifToggleDisabled));

  return OK_STATUS();
}

bool test_main(void) {
  LOG_INFO("hello");
  CHECK_STATUS_OK(test_init());
  CHECK_STATUS_OK(enter_sleep());
  return true;
}
