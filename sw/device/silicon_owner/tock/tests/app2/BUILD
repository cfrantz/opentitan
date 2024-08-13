# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("@bazel_skylib//lib:dicts.bzl", "dicts")
load("@rules_rust//rust:defs.bzl", "rust_binary")
load("//rules:signing.bzl", "sign_bin")
load("//rules:tock.bzl", "TOCK_ENVS", "tock_elf2tab", "tock_image")
load("//rules/opentitan:defs.bzl", "EARLGREY_SILICON_OWNER_ROM_EXT_ENVS", "OPENTITAN_CPU", "fpga_params", "opentitan_test", "silicon_params")
load("//rules:linker.bzl", "ld_library")

package(default_visibility = ["//visibility:public"])

ld_library(
    name = "second_app_layout",
    script = "second_app_layout.ld",
    deps = [
        "//sw/device/silicon_owner/tock/apps:libtock_layout",
    ],
)

rust_binary(
    name = "basic",
    srcs = [
        "src/basic.rs",
    ],
    rustc_flags = [
        #"-Clinker=rust-lld",
        #"-Clinker-flavor=ld.lld",
    ],
    # We specifically restrict our build target to the OpenTitan
    # CPU because libtock does not support an x86_64 target.
    target_compatible_with = [OPENTITAN_CPU],
    deps = [
        ":second_app_layout",
        "@libtock",
    ],
)

tock_elf2tab(
    name = "tab",
    package_name = "goodbye",
    src = ":basic",
    arch = "rv32imc",
    flash_start = 0x20048000,
)

tock_image(
    name = "image_fpga",
    testonly = True,
    apps = [
        "//sw/device/silicon_owner/tock/tests/basic:tab",
        ":tab",
    ],
    exec_env = "//hw/top_earlgrey:fpga_cw310_sival_rom_ext",
    kernel = "//sw/device/silicon_owner/tock/tests:test_kernel_fpga",
)

tock_image(
    name = "image_silicon",
    apps = [":tab"],
    exec_env = "//hw/top_earlgrey:silicon_owner_sival_rom_ext",
    kernel = "//sw/device/silicon_owner/tock/tests:test_kernel_silicon",
)

opentitan_test(
    name = "basic_test",
    exec_env = TOCK_ENVS,
    fpga = fpga_params(
        binaries = {":image_fpga": "firmware"},
    ),
    #silicon = silicon_params(
    #    binaries = {":image_silicon": "firmware"},
    #),
)
