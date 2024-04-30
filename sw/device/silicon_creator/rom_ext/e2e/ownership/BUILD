# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load(
    "//rules/opentitan:defs.bzl",
    "cw310_params",
    "opentitan_test",
)

package(default_visibility = ["//visibility:public"])

opentitan_test(
    name = "ownership_transfer_test",
    srcs = ["//sw/device/silicon_creator/rom_ext/e2e/verified_boot:boot_test"],
    cw310 = cw310_params(
        data = [
            "//sw/device/silicon_creator/lib/ownership/keys/dummy:activate_key",
            "//sw/device/silicon_creator/lib/ownership/keys/dummy:app_prod_pub",
            "//sw/device/silicon_creator/lib/ownership/keys/dummy:owner_key",
            "//sw/device/silicon_creator/lib/ownership/keys/dummy:unlock_key",
            "//sw/device/silicon_creator/lib/ownership/keys/fake:unlock_key",
        ],
        test_cmd = """
            --clear-bitstream
            --bootstrap={firmware}
            --unlock-key=$(location //sw/device/silicon_creator/lib/ownership/keys/fake:unlock_key)
            --next-owner-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:owner_key)
            --next-unlock-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:unlock_key)
            --next-activate-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:activate_key)
            --next-application-key=$(location //sw/device/silicon_creator/lib/ownership/keys/dummy:app_prod_pub)
        """,
        test_harness = "//sw/host/tests/ownership:transfer_test",
    ),
    exec_env = {
        "//hw/top_earlgrey:fpga_cw310_rom_ext": None,
    },
    rsa_key = {
        "//sw/device/silicon_creator/lib/ownership/keys/dummy:app_prod": "app_prod",
    },
    deps = [
        "//sw/device/lib/base:status",
        "//sw/device/lib/testing/test_framework:ottf_main",
        "//sw/device/silicon_creator/lib:boot_log",
        "//sw/device/silicon_creator/lib/drivers:retention_sram",
    ],
)
