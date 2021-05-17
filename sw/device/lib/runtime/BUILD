package(default_visibility = ["//visibility:public"])
load("//rules:opentitan.bzl", "OPENTITAN_CPU")


cc_library(
    name = "epmp",
    srcs = ["epmp.c"],
    hdrs = ["epmp.h"],
    deps = [
        "//sw/device/lib/base/freestanding",
    ],
    target_compatible_with = [OPENTITAN_CPU],
)

cc_library(
    name = "hart",
    srcs = ["hart.c"],
    hdrs = ["hart.h"],
    deps = [
        ":ibex",
        "//sw/device/lib/arch:device",
        "//sw/device/lib/base",
        "//sw/device/lib/base/freestanding",
    ],
    target_compatible_with = [OPENTITAN_CPU],
)
cc_library(
    name = "ibex",
    srcs = ["ibex.c"],
    hdrs = ["ibex.h"],
    deps = [
        "//sw/device/lib/base",
    ],
    target_compatible_with = [OPENTITAN_CPU],
)
cc_library(
    name = "log",
    srcs = ["log.c"],
    hdrs = ["log.h"],
    deps = [
        "//sw/device/lib/arch:device",
        "//sw/device/lib/base",
        "//sw/device/lib/base/freestanding",
        "//sw/device/lib/runtime:print",
    ],
    target_compatible_with = [OPENTITAN_CPU],
)
cc_library(
    name = "otbn",
    srcs = ["otbn.c"],
    hdrs = ["otbn.h"],
    deps = [
        "//sw/device/lib/dif:dif_otbn",
    ],
)
cc_library(
    name = "pmp",
    srcs = ["pmp.c"],
    hdrs = ["pmp.h"],
    textual_hdrs = ["pmp_regions.def"],
    deps = [
        "//sw/device/lib/base",
        "//sw/device/lib/base/freestanding",
    ],
    target_compatible_with = [OPENTITAN_CPU],
)

cc_library(
    name = "print",
    srcs = ["print.c"],
    hdrs = ["print.h"],
    deps = [
        "//sw/device/lib/base",
#        "//sw/device/lib/base/freestanding",
        "//sw/device/lib/dif:dif_uart",
    ],
)

cc_test(
    name = "print_unittest",
    srcs = ["print_unittest.cc"],
    deps = [
        ":print",
        "//sw/device/lib/base/testing",
        "@googletest//:gtest",
        "@googletest//:gtest_main",
    ],
)
