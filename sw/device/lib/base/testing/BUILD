package(default_visibility = ["//visibility:public"])

cc_library(
    name = "testing",
    defines = [
        "MOCK_MMIO=1",
        "MOCK_CSR=1",
    ],
    hdrs = [
        "mock_csr.h",
        "mock_mmio.h",
        "mock_mmio_test_utils.h",

    ],
    srcs = [
        "mock_csr.cc",
        "mock_mmio.cc",
        "//sw/device/lib/base:mmio_src",
    ],
    deps = [
        "//sw/device/lib/base",
        "//sw/device/lib/testing:mask_rom_test",
        "@googletest//:gtest",
    ],
)

cc_test(
    name = "mock_csr_test",
    srcs = [ "mock_csr_test.cc" ],
    deps = [
        ":testing",
        "@googletest//:gtest_main",
    ],
)

cc_test(
    name = "mock_mmio_test",
    srcs = [ "mock_mmio_test.cc" ],
    deps = [
        ":testing",
        "@googletest//:gtest_main",
    ],
)
