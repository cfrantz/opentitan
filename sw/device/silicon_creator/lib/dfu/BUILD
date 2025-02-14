# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load(
    "@bazel_skylib//lib:dicts.bzl",
    "dicts",
)
load(
    "//rules/opentitan:defs.bzl",
    "EARLGREY_SILICON_OWNER_ROM_EXT_ENVS",
    "EARLGREY_TEST_ENVS",
    "fpga_params",
    "opentitan_test",
    "silicon_params",
    "verilator_params",
)

package(default_visibility = ["//visibility:public"])

cc_library(
    name = "dfu",
    srcs = [
        "dfu_state_table.c",
    ],
    hdrs = [
        "dfu.h",
    ],
    deps = [
    ],
)

opentitan_test(
    name = "dfu_functest",
    srcs = ["dfu_usb.c"],
    exec_env = dicts.add(
        EARLGREY_TEST_ENVS,
        EARLGREY_SILICON_OWNER_ROM_EXT_ENVS,
    ),
    silicon = silicon_params(
        test_cmd = """
            --bootstrap={firmware}
        """,
        test_harness = "//sw/host/tests/chip/usb:usb_harness",
    ),
    verilator = verilator_params(
        timeout = "long",
    ),
    deps = [
        ":dfu",
        "//sw/device/lib/base:macros",
        "//sw/device/lib/testing/test_framework:ottf_main",
        "//sw/device/silicon_creator/lib/drivers:pinmux",
        "//sw/device/silicon_creator/lib/drivers:usb",
    ],
)
