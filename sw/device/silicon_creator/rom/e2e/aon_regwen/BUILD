# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load(
    "//rules/opentitan:defs.bzl",
    "cw310_params",
    "opentitan_test",
)
load(
    "//rules:const.bzl",
    "CONST",
)
load(
    "//rules:otp.bzl",
    "STD_OTP_OVERLAYS",
    "otp_hex",
    "otp_image",
    "otp_json",
    "otp_partition",
)
load(
    "//rules:rom_e2e.bzl",
    "maybe_skip_in_ci",
)

package(default_visibility = ["//visibility:public"])

REGWENS = {
    "clkmgr": "kRegwenClkmgrJitter",
    "pinmux": "kRegwenPinmux",
    "pwrmgr": "kRegwenPwrmgrResetEn",
    "retram": "kRegwenRetRamSramCtrl",
    "rstmgr": "kRegwenRstmgrAlert",
    "wdog": "kRegwenAonTimerWdog",
}

[
opentitan_test(
    name = "rom_e2e_regwen_{}_test".format(name),
    srcs = ["rom_e2e_regwen_boot_test.c"],
    defines = [
        "REGWEN={}".format(value),
    ],
    cw310 = cw310_params(
        tags = maybe_skip_in_ci(CONST.LCV.RMA),
    ),
    exec_env = {
        "//hw/top_earlgrey:fpga_cw310_rom_with_fake_keys": None,
    },
    deps = [
        "//hw/top_earlgrey/ip_autogen/clkmgr/data:clkmgr_c_regs",
        "//hw/top_earlgrey/ip/pinmux/data/autogen:pinmux_c_regs",
        "//hw/top_earlgrey/ip_autogen/pwrmgr/data:pwrmgr_c_regs",
        "//hw/ip/sram_ctrl/data:sram_ctrl_c_regs",
        "//hw/top_earlgrey/ip_autogen/rstmgr/data:rstmgr_c_regs",
        "//hw/ip/aon_timer/data:aon_timer_c_regs",
        "//sw/device/lib/base:abs_mmio",
        "//sw/device/lib/base:memory",
        "//sw/device/lib/dif:aon_timer",
        "//sw/device/lib/dif:pwrmgr",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/testing:aon_timer_testutils",
        "//sw/device/lib/testing:pwrmgr_testutils",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_main",
        "//sw/device/silicon_creator/lib/drivers:retention_sram",
        "//sw/device/silicon_creator/lib/drivers:rstmgr",
    ],
)
for name, value in REGWENS.items()
]

test_suite(
    name = "rom_e2e_regwen_test",
    tags = ["manual"],
    tests = [
        ":rom_e2e_regwen_{}_test".format(name)
        for name in REGWENS.keys()
    ],
)
