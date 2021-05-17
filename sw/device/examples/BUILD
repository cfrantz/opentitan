package(default_visibility = ["//visibility:public"])
load("//rules:opentitan.bzl", "OPENTITAN_CPU")

cc_library(
    name = "demos",
    hdrs = ["demos.h"],
    srcs = ["demos.c"],
    deps = [
        "//sw/device/lib/arch:device",
        "//sw/device/lib/dif:dif_gpio",
        "//sw/device/lib/dif:dif_spi_device",
        "//sw/device/lib/dif:dif_uart",
        "//sw/device/lib/runtime:hart",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/testing",
    ],
    #target_compatible_with = [OPENTITAN_CPU],
)

