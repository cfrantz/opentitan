package(default_visibility = ["//visibility:public"])
load("//rules:opentitan.bzl", "OPENTITAN_CPU")

cc_library(
    name = "mask_rom_test",
    hdrs = [
        "mask_rom_test.h",
    ],
    deps = [
        "@googletest//:gtest",
    ],
)

cc_library(
    name = "testing",
    hdrs = [
        "check.h",
        "test_coverage.h",
        "test_status.h",
    ],
    srcs = [
        #"test_coverage_llvm.c",
        "test_coverage_none.c",
        "test_status.c",
    ],
    deps = [
        "//sw/device/lib/arch:device",
        "//sw/device/lib/base",
        "//sw/device/lib/dif:dif_uart",
        "//sw/device/lib/runtime:hart",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/runtime:print",
        "//hw/top_earlgrey/sw/autogen:top_earlgrey",
    ],
    target_compatible_with = [OPENTITAN_CPU],
)

cc_library(
    name = "main",
    hdrs = [
        "test_main.h",
    ],
    srcs = [
        "test_main.c",
    ],
    deps = [
        ":testing",
    ],
    target_compatible_with = [OPENTITAN_CPU],
)
