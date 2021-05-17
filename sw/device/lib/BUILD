package(default_visibility = ["//visibility:public"])
load("//rules:opentitan.bzl", "OPENTITAN_CPU")

cc_library(
    name = "flash_ctrl",
    hdrs = ["flash_ctrl.h"],
    srcs = ["flash_ctrl.c"],
    deps = [
        "//:flash_ctrl_regs",
        "//sw/device/lib/base",
        "//hw/top_earlgrey/sw/autogen:top_earlgrey",
    ],
    target_compatible_with = [OPENTITAN_CPU],
)

cc_library(
    name = "irq",
    hdrs = [
        "handler.h",
        "irq.h",
    ],
    srcs = [
        "handler.c",
        "irq.c",
    ],
    deps = [
        "//sw/device/lib/base",
        "//sw/device/lib/runtime:log",
        "//hw/top_earlgrey/sw/autogen:top_earlgrey",
    ],
    target_compatible_with = [OPENTITAN_CPU],
)

cc_library(
    name = "pinmux",
    hdrs = ["pinmux.h"],
    srcs = ["pinmux.c"],
    deps = [
        "//:pinmux_regs",
        "//sw/device/lib/base",
        "//hw/top_earlgrey/sw/autogen:top_earlgrey",
    ],
    target_compatible_with = [OPENTITAN_CPU],
)
