package(default_visibility = ["//visibility:public"])


cc_library(
    name = "absl_status",
    hdrs = ["absl_status.h"],
    visibility = ["//visibility:private"],
)

cc_library(
    name = "error",
    hdrs = ["error.h"],
    deps = [":absl_status"],
)

cc_test(
    name = "error_unittest",
    srcs = ["error_unittest.cc"],
    deps = [
        ":error",
        "//sw/device/lib/base",
        "@googletest//:gtest",
        "@googletest//:gtest_main",
    ],
)


