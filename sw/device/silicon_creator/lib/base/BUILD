package(default_visibility = ["//visibility:public"])


cc_library(
    name = "abs_mmio",
    hdrs = ["abs_mmio.h"],
    srcs = ["abs_mmio.c"],
    deps = [
        "//sw/device/lib/base",
    ],
)

cc_library(
    name = "mock_abs_mmio",
    defines = [
        "MOCK_ABS_MMIO=1",
    ],
    hdrs = [
        "abs_mmio.h",
        "mock_abs_mmio.h",
    ],
    deps = [
        ":abs_mmio",
        "//sw/device/lib/base",
        "//sw/device/lib/testing:mask_rom_test",
    ],
)
