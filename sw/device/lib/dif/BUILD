package(default_visibility = ["//visibility:public"])

cc_library(
    name = "dif_warn_unused_result",
    hdrs = ["dif_warn_unused_result.h"],
)

cc_library(
    name = "dif_aes",
    hdrs = ["dif_aes.h"],
    srcs = ["dif_aes.c"],
    deps = [
        ":dif_warn_unused_result",
        "//:aes_regs",
        "//sw/device/lib/base",
    ],
)

cc_test(
    name = "dif_aes_unittest",
    srcs = ["dif_aes_unittest.cc"],
    deps = [
        ":dif_aes",
        "//sw/device/lib/base",
        "//sw/device/lib/base/testing",
        "@googletest//:gtest",
        "@googletest//:gtest_main",
    ],
)

cc_library(
    name = "dif_alert_handler",
    hdrs = ["dif_alert_handler.h"],
    srcs = ["dif_alert_handler.c"],
    deps = [
        ":dif_warn_unused_result",
        "//:alert_handler_regs",
        "//sw/device/lib/base",
    ],
)

cc_test(
    name = "dif_alert_handler_unittest",
    srcs = ["dif_alert_handler_unittest.cc"],
    deps = [
        ":dif_alert_handler",
        "//sw/device/lib/base",
        "//sw/device/lib/base/testing",
        "@googletest//:gtest",
        "@googletest//:gtest_main",
    ],
)

cc_library(
    name = "dif_aon_timer",
    hdrs = ["dif_aon_timer.h"],
    srcs = ["dif_aon_timer.c"],
    deps = [
        ":dif_warn_unused_result",
        "//:aon_timer_regs",
        "//sw/device/lib/base",
    ],
)

cc_test(
    name = "dif_aon_timer_unittest",
    srcs = ["dif_aon_timer_unittest.cc"],
    deps = [
        ":dif_aon_timer",
        "//sw/device/lib/base",
        "//sw/device/lib/base/testing",
        "@googletest//:gtest",
        "@googletest//:gtest_main",
    ],
)

cc_library(
    name = "dif_clkmgr",
    hdrs = ["dif_clkmgr.h"],
    srcs = ["dif_clkmgr.c"],
    deps = [
        ":dif_warn_unused_result",
        "//:clkmgr_regs",
        "//sw/device/lib/base",
    ],
)

cc_test(
    name = "dif_clkmgr_unittest",
    srcs = ["dif_clkmgr_unittest.cc"],
    deps = [
        ":dif_clkmgr",
        "//sw/device/lib/base",
        "//sw/device/lib/base/testing",
        "@googletest//:gtest",
        "@googletest//:gtest_main",
    ],
)

cc_library(
    name = "dif_csrng",
    hdrs = ["dif_csrng.h"],
    srcs = ["dif_csrng.c"],
    deps = [
        ":dif_warn_unused_result",
        "//:csrng_regs",
        "//sw/device/lib/base",
    ],
)

cc_test(
    name = "dif_csrng_unittest",
    srcs = ["dif_csrng_unittest.cc"],
    deps = [
        ":dif_csrng",
        "//sw/device/lib/base",
        "//sw/device/lib/base/testing",
        "@googletest//:gtest",
        "@googletest//:gtest_main",
    ],
)

cc_library(
    name = "dif_edn",
    hdrs = ["dif_edn.h"],
    srcs = ["dif_edn.c"],
    deps = [
        ":dif_warn_unused_result",
        "//:edn_regs",
        "//sw/device/lib/base",
    ],
)

##cc_test(
##    name = "dif_edn_unittest",
##    srcs = ["dif_edn_unittest.cc"],
##    deps = [
##        ":dif_edn",
##        "//:edn_regs",
##        "//sw/device/lib/base",
##        "//sw/device/lib/base/testing",
##        "@googletest//:gtest",
##        "@googletest//:gtest_main",
##    ],
##)
##
cc_library(
    name = "dif_entropy",
    hdrs = ["dif_entropy.h"],
    srcs = ["dif_entropy.c"],
    deps = [
        ":dif_warn_unused_result",
        "//:entropy_src_regs",
        "//sw/device/lib/base",
    ],
)

cc_test(
    name = "dif_entropy_unittest",
    defines = ["MOCK_MMIO=1"],
    srcs = ["dif_entropy_unittest.cc",
            ],
    deps = [
        ":dif_entropy",
        "//sw/device/lib/base",
        "//sw/device/lib/base/testing",
        "@googletest//:gtest",
        "@googletest//:gtest_main",
    ],
)

cc_library(
    name = "dif_gpio",
    hdrs = ["dif_gpio.h"],
    srcs = ["dif_gpio.c"],
    deps = [
        ":dif_warn_unused_result",
        "//:gpio_regs",
        "//sw/device/lib/base",
    ],
)

cc_test(
    name = "dif_gpio_unittest",
    srcs = ["dif_gpio_unittest.cc"],
    deps = [
        ":dif_gpio",
        "//sw/device/lib/base",
        "//sw/device/lib/base/testing",
        "@googletest//:gtest",
        "@googletest//:gtest_main",
    ],
)

cc_library(
    name = "dif_hmac",
    hdrs = ["dif_hmac.h"],
    srcs = ["dif_hmac.c"],
    deps = [
        ":dif_warn_unused_result",
        "//:hmac_regs",
        "//sw/device/lib/base",
    ],
)

##cc_test(
##    name = "dif_hmac_unittest",
##    srcs = ["dif_hmac_unittest.cc"],
##    deps = [
##        ":dif_hmac",
##        "//sw/device/lib/base",
##        "//sw/device/lib/base/testing",
##        "@googletest//:gtest",
##        "@googletest//:gtest_main",
##    ],
##)

cc_library(
    name = "dif_i2c",
    hdrs = ["dif_i2c.h"],
    srcs = ["dif_i2c.c"],
    deps = [
        ":dif_warn_unused_result",
        "//:i2c_regs",
        "//sw/device/lib/base",
    ],
)

cc_test(
    name = "dif_i2c_unittest",
    srcs = ["dif_i2c_unittest.cc"],
    deps = [
        ":dif_i2c",
        "//sw/device/lib/base",
        "//sw/device/lib/base/testing",
        "@googletest//:gtest",
        "@googletest//:gtest_main",
    ],
)

cc_library(
    name = "dif_keymgr",
    hdrs = ["dif_keymgr.h"],
    srcs = ["dif_keymgr.c"],
    deps = [
        ":dif_warn_unused_result",
        "//:keymgr_regs",
        "//sw/device/lib/base",
    ],
)

cc_test(
    name = "dif_keymgr_unittest",
    srcs = ["dif_keymgr_unittest.cc"],
    deps = [
        ":dif_keymgr",
        "//sw/device/lib/base",
        "//sw/device/lib/base/testing",
        "@googletest//:gtest",
        "@googletest//:gtest_main",
    ],
)

cc_library(
    name = "dif_kmac",
    hdrs = ["dif_kmac.h"],
    srcs = ["dif_kmac.c"],
    deps = [
        ":dif_warn_unused_result",
        "//:kmac_regs",
        "//sw/device/lib/base",
    ],
)

cc_test(
    name = "dif_kmac_unittest",
    srcs = ["dif_kmac_unittest.cc"],
    deps = [
        ":dif_kmac",
        "//sw/device/lib/base",
        "//sw/device/lib/base/testing",
        "@googletest//:gtest",
        "@googletest//:gtest_main",
    ],
)

cc_library(
    name = "dif_lc_ctrl",
    hdrs = ["dif_lc_ctrl.h"],
    srcs = ["dif_lc_ctrl.c"],
    deps = [
        ":dif_warn_unused_result",
        "//:lc_ctrl_regs",
        "//sw/device/lib/base",
    ],
)

cc_test(
    name = "dif_lc_ctrl_unittest",
    srcs = ["dif_lc_ctrl_unittest.cc"],
    deps = [
        ":dif_lc_ctrl",
        "//sw/device/lib/base",
        "//sw/device/lib/base/testing",
        "@googletest//:gtest",
        "@googletest//:gtest_main",
    ],
)

cc_library(
    name = "dif_otbn",
    hdrs = ["dif_otbn.h"],
    srcs = ["dif_otbn.c"],
    deps = [
        ":dif_warn_unused_result",
        "//:otbn_regs",
        "//sw/device/lib/base",
    ],
)

cc_test(
    name = "dif_otbn_unittest",
    srcs = ["dif_otbn_unittest.cc"],
    deps = [
        ":dif_otbn",
        "//sw/device/lib/base",
        "//sw/device/lib/base/testing",
        "@googletest//:gtest",
        "@googletest//:gtest_main",
    ],
)

cc_library(
    name = "dif_otp_ctrl",
    hdrs = ["dif_otp_ctrl.h"],
    srcs = ["dif_otp_ctrl.c"],
    deps = [
        ":dif_warn_unused_result",
        "//:otp_ctrl_regs",
        "//sw/device/lib/base",
    ],
)

cc_test(
    name = "dif_otp_ctrl_unittest",
    srcs = ["dif_otp_ctrl_unittest.cc"],
    deps = [
        ":dif_otp_ctrl",
        "//sw/device/lib/base",
        "//sw/device/lib/base/testing",
        "@googletest//:gtest",
        "@googletest//:gtest_main",
    ],
)

cc_library(
    name = "dif_pinmux",
    hdrs = ["dif_pinmux.h"],
    srcs = ["dif_pinmux.c"],
    deps = [
        ":dif_warn_unused_result",
        "//:pinmux_regs",
        "//sw/device/lib/base",
    ],
)

##cc_test(
##    name = "dif_pinmux_unittest",
##    srcs = ["dif_pinmux_unittest.cc"],
##    deps = [
##        ":dif_pinmux",
##        "//sw/device/lib/base",
##        "//sw/device/lib/base/testing",
##        "@googletest//:gtest",
##        "@googletest//:gtest_main",
##    ],
##)

cc_library(
    name = "dif_plic",
    hdrs = ["dif_plic.h"],
    srcs = ["dif_plic.c"],
    deps = [
        ":dif_warn_unused_result",
        "//:rv_plic_regs",
        "//sw/device/lib/base",
    ],
)

cc_test(
    name = "dif_plic_unittest",
    srcs = ["dif_plic_unittest.cc"],
    deps = [
        ":dif_plic",
        "//sw/device/lib/base",
        "//sw/device/lib/base/testing",
        "@googletest//:gtest",
        "@googletest//:gtest_main",
    ],
)

cc_library(
    name = "dif_pwrmgr",
    hdrs = ["dif_pwrmgr.h"],
    srcs = ["dif_pwrmgr.c"],
    deps = [
        ":dif_warn_unused_result",
        "//:pwrmgr_regs",
        "//sw/device/lib/base",
    ],
)

cc_test(
    name = "dif_pwrmgr_unittest",
    srcs = ["dif_pwrmgr_unittest.cc"],
    deps = [
        ":dif_pwrmgr",
        "//sw/device/lib/base",
        "//sw/device/lib/base/testing",
        "@googletest//:gtest",
        "@googletest//:gtest_main",
    ],
)

cc_library(
    name = "dif_rstmgr",
    hdrs = ["dif_rstmgr.h"],
    srcs = ["dif_rstmgr.c"],
    deps = [
        ":dif_warn_unused_result",
        "//:rstmgr_regs",
        "//sw/device/lib/base",
    ],
)

cc_test(
    name = "dif_rstmgr_unittest",
    srcs = ["dif_rstmgr_unittest.cc"],
    deps = [
        ":dif_rstmgr",
        "//sw/device/lib/base",
        "//sw/device/lib/base/testing",
        "@googletest//:gtest",
        "@googletest//:gtest_main",
    ],
)

cc_library(
    name = "dif_rv_timer",
    hdrs = ["dif_rv_timer.h"],
    srcs = ["dif_rv_timer.c"],
    deps = [
        ":dif_warn_unused_result",
        "//:rv_timer_regs",
        "//sw/device/lib/base",
    ],
)

cc_test(
    name = "dif_rv_timer_unittest",
    srcs = ["dif_rv_timer_unittest.cc"],
    deps = [
        ":dif_rv_timer",
        "//sw/device/lib/base",
        "//sw/device/lib/base/testing",
        "@googletest//:gtest",
        "@googletest//:gtest_main",
    ],
)

cc_library(
    name = "dif_spi_device",
    hdrs = ["dif_spi_device.h"],
    srcs = ["dif_spi_device.c"],
    deps = [
        ":dif_warn_unused_result",
        "//:spi_device_regs",
        "//sw/device/lib/base",
    ],
)

cc_test(
    name = "dif_spi_device_unittest",
    srcs = ["dif_spi_device_unittest.cc"],
    deps = [
        ":dif_spi_device",
        "//sw/device/lib/base",
        "//sw/device/lib/base/testing",
        "@googletest//:gtest",
        "@googletest//:gtest_main",
    ],
)

cc_library(
    name = "dif_sram_ctrl",
    hdrs = ["dif_sram_ctrl.h"],
    srcs = ["dif_sram_ctrl.c"],
    deps = [
        ":dif_warn_unused_result",
        "//sw/device/lib/base",
    ],
)

## Missing?
##cc_test(
##    name = "dif_sram_ctrl_unittest",
##    srcs = ["dif_sram_ctrl_unittest.cc"],
##    deps = [
##        ":dif_sram_ctrl",
##        "//sw/device/lib/base",
##        "//sw/device/lib/base/testing",
##        "@googletest//:gtest",
##        "@googletest//:gtest_main",
##    ],
##)

cc_library(
    name = "dif_uart",
    hdrs = ["dif_uart.h"],
    srcs = ["dif_uart.c"],
    deps = [
        "//:uart_regs",
        ":dif_warn_unused_result",
        "//sw/device/lib/base",
    ],
)

cc_test(
    name = "dif_uart_unittest",
    srcs = ["dif_uart_unittest.cc"],
    deps = [
        ":dif_uart",
        "//sw/device/lib/base",
        "//sw/device/lib/base/testing",
        "@googletest//:gtest",
        "@googletest//:gtest_main",
    ],
)

cc_library(
    name = "dif_usbdev",
    hdrs = ["dif_usbdev.h"],
    srcs = ["dif_usbdev.c"],
    deps = [
        ":dif_warn_unused_result",
        "//:usbdev_regs",
        "//sw/device/lib/base",
    ],
)

##cc_test(
##    name = "dif_usbdev_unittest",
##    srcs = ["dif_usbdev_unittest.cc"],
##    deps = [
##        ":dif_usbdev",
##        "//sw/device/lib/base",
##        "//sw/device/lib/base/testing",
##        "@googletest//:gtest",
##        "@googletest//:gtest_main",
##    ],
##)

