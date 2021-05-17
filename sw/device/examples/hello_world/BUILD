package(default_visibility = ["//visibility:public"])
load("//rules:autogen.bzl", "chip_info")
load("//rules:opentitan.bzl", "OPENTITAN_CPU", "opentitan_binary")

opentitan_binary(
    name = "hello_world",
    copts = [
        "-nostdlib",
        "-ffreestanding",
        # Disable the date-time warning only for the hello world program.
        "-Wno-date-time",
    ],
    linkopts = [
        "-nostartfiles",
        "-nostdlib",
    ],
    srcs = [
        "hello_world.c",
    ],
    deps = [
        ":hello_world_lib",
        "//sw/device/lib/base:mmio",
    ],
)

cc_library(
    name = "hello_world_lib",
    deps = [
        "//sw/device/exts/common",
        "//sw/device/examples:demos",
        "//sw/device/lib/arch:device",
        "//sw/device/lib/crt",
        "//sw/device/lib/dif:dif_gpio",
        "//sw/device/lib/dif:dif_spi_device",
        "//sw/device/lib/dif:dif_uart",
        "//sw/device/lib:irq",
        "//sw/device/lib:pinmux",
        "//sw/device/lib/runtime:hart",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/runtime:print",
        "//sw/device/lib/testing",
        "//hw/top_earlgrey/sw/autogen:top_earlgrey",
    ],
    target_compatible_with = [OPENTITAN_CPU],
)


