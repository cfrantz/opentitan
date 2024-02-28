# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load(
    "//rules/opentitan:defs.bzl",
    "EARLGREY_TEST_ENVS",
    "cw310_params",
    "opentitan_test",
    "verilator_params",
)

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "datatypes",
    hdrs = ["datatypes.h"],
)

cc_library(
    name = "owner_keys",
    srcs = ["owner_keys.c"],
    hdrs = ["owner_keys.h"],
    deps = [
        ":datatypes",
        "//sw/device/lib/base:macros",
    ],
)

cc_library(
    name = "ecdsa",
    srcs = ["ecdsa.c"],
    hdrs = ["ecdsa.h"],
    defines = ["USE_CRYPTOC=1"],
    deps = [
        ":datatypes",
        "//sw/device/lib/base:hardened",
        "//sw/device/lib/base:macros",
        "//sw/vendor:cryptoc",
    ],
)

# Enable this test when ownership/keys/fake exists.
#opentitan_test(
#    name = "ecdsa_functest",
#    srcs = ["ecdsa_functest.c"],
#    exec_env = {
#        "//hw/top_earlgrey:fpga_cw310_rom_with_fake_keys": None,
#    },
#    deps = [
#        ":ecdsa",
#        "//sw/device/lib/base:hardened",
#        "//sw/device/lib/base:status",
#        "//sw/device/lib/runtime:log",
#        "//sw/device/lib/testing:entropy_testutils",
#        "//sw/device/lib/testing:hexstr",
#        "//sw/device/lib/testing/test_framework:ottf_main",
#        "//sw/device/silicon_creator/lib/ownership/keys/fake",
#    ],
#)

cc_library(
    name = "ownership",
    srcs = ["ownership.c"],
    hdrs = ["ownership.h"],
    deps = [
        ":datatypes",
        ":ecdsa",
        ":owner_keys",
        "//sw/device/silicon_creator/lib/drivers:flash_ctrl",
    ],
)

cc_library(
    name = "ownership_unlock",
    srcs = ["ownership_unlock.c"],
    hdrs = ["ownership_unlock.h"],
    deps = [
        ":datatypes",
        ":ecdsa",
        ":ownership",
        "//sw/device/lib/base:memory",
        "//sw/device/silicon_creator/lib:boot_data",
        "//sw/device/silicon_creator/lib:error",
        "//sw/device/silicon_creator/lib/boot_svc:boot_svc_msg",
        "//sw/device/silicon_creator/lib/drivers:flash_ctrl",
    ],
)
