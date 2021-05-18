package(default_visibility = ["//visibility:public"])
load("//rules:opentitan.bzl", "OPENTITAN_CPU", "opentitan_binary", "opentitan_functest")



cc_library(
    name = "hmac",
    hdrs = ["hmac.h"],
    srcs = ["hmac.c"],
    deps = [
        "//:hmac_regs",
        "//sw/device/lib/arch:device",
        "//sw/device/lib/base",
        "//sw/device/silicon_creator/lib/base:abs_mmio",
        "//sw/device/silicon_creator/lib:error",
        "//hw/top_earlgrey/sw/autogen:top_earlgrey",
    ],
)

cc_test(
    name = "hmac_unittest",
    srcs = ["hmac_unittest.cc"],
    deps = [
        ":hmac",
        "//sw/device/lib/base",
        "//sw/device/lib/base/testing",
        "//sw/device/silicon_creator/lib/base:mock_abs_mmio",
        "@googletest//:gtest",
        "@googletest//:gtest_main",
    ],
)

opentitan_functest(
    name = "hmac_functest",
    copts = [
        "-nostdlib",
        "-ffreestanding",
    ],
    linkopts = [
        "-nostartfiles",
        "-nostdlib",
    ],
    srcs = [
        "hmac_functest.c",
    ],
    deps = [
        ":hmac",
        "//sw/device/exts/common",
        "//sw/device/lib/base",
        "//sw/device/lib/base:mmio",
        "//sw/device/lib/arch:device",
        "//sw/device/lib/crt",
        "//sw/device/lib:irq",
        "//sw/device/lib:pinmux",
        "//sw/device/lib/runtime:hart",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/runtime:print",
        "//sw/device/lib/testing",
        "//sw/device/lib/testing:main",
        "//hw/top_earlgrey/sw/autogen:top_earlgrey",
    ],
)


cc_library(
    name = "otp",
    hdrs = ["otp.h"],
    srcs = ["otp.c"],
    deps = [
        "//:otp_ctrl_regs",
        "//sw/device/lib/arch:device",
        "//sw/device/lib/base",
        "//sw/device/silicon_creator/lib:error",
    ],
)

cc_test(
    name = "otp_unittest",
    srcs = ["otp_unittest.cc"],
    deps = [
        ":otp",
        "//sw/device/lib/base",
        "//sw/device/lib/base/testing",
        "@googletest//:gtest",
        "@googletest//:gtest_main",
    ],
)

cc_library(
    name = "uart",
    hdrs = ["uart.h"],
    srcs = ["uart.c"],
    deps = [
        "//:uart_regs",
        "//sw/device/lib/arch:device",
        "//sw/device/lib/base",
        "//sw/device/silicon_creator/lib:error",
    ],
)

cc_test(
    name = "uart_unittest",
    srcs = ["uart_unittest.cc"],
    deps = [
        ":uart",
        "//sw/device/lib/base",
        "//sw/device/lib/base/testing",
        "@googletest//:gtest",
        "@googletest//:gtest_main",
    ],
)

opentitan_functest(
    name = "uart_functest",
    copts = [
        "-nostdlib",
        "-ffreestanding",
    ],
    linkopts = [
        "-nostartfiles",
        "-nostdlib",
    ],
    srcs = [
        "uart_functest.c",
    ],
    deps = [
        ":uart",
        "//sw/device/exts/common",
        "//sw/device/lib/base",
        "//sw/device/lib/base:mmio",
        "//sw/device/lib/arch:device",
        "//sw/device/lib/crt",
        "//sw/device/lib:irq",
        "//sw/device/lib:pinmux",
        "//sw/device/lib/runtime:hart",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/runtime:print",
        "//sw/device/lib/testing",
        "//sw/device/lib/testing:main",
        "//hw/top_earlgrey/sw/autogen:top_earlgrey",
    ],
)
