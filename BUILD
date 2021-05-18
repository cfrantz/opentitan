package(default_visibility = ["//visibility:public"])

load("//rules:autogen.bzl", "autogen_hjson_header", "otp_image")

autogen_hjson_header(
    name = "aes_regs",
    srcs = [
        "//hw:ip/aes/data/aes.hjson",
    ],
)

autogen_hjson_header(
    name = "aon_timer_regs",
    srcs = [
        "//hw:ip/aon_timer/data/aon_timer.hjson",
    ],
)

autogen_hjson_header(
    name = "csrng_regs",
    srcs = [
        "//hw:ip/csrng/data/csrng.hjson",
    ],
)

autogen_hjson_header(
    name = "edn_regs",
    srcs = [
        "//hw:ip/edn/data/edn.hjson",
    ],
)

autogen_hjson_header(
    name = "entropy_src_regs",
    srcs = [
        "//hw:ip/entropy_src/data/entropy_src.hjson",
    ],
)

autogen_hjson_header(
    name = "gpio_regs",
    srcs = [
        "//hw:ip/gpio/data/gpio.hjson",
    ],
)

autogen_hjson_header(
    name = "hmac_regs",
    srcs = [
        "//hw:ip/hmac/data/hmac.hjson",
    ],
)

autogen_hjson_header(
    name = "i2c_regs",
    srcs = [
        "//hw:ip/i2c/data/i2c.hjson",
    ],
)

autogen_hjson_header(
    name = "keymgr_regs",
    srcs = [
        "//hw:ip/keymgr/data/keymgr.hjson",
    ],
)

autogen_hjson_header(
    name = "kmac_regs",
    srcs = [
        "//hw:ip/kmac/data/kmac.hjson",
    ],
)

autogen_hjson_header(
    name = "lc_ctrl_regs",
    srcs = [
        "//hw:ip/lc_ctrl/data/lc_ctrl.hjson",
    ],
)

autogen_hjson_header(
    name = "otbn_regs",
    srcs = [
        "//hw:ip/otbn/data/otbn.hjson",
    ],
)

autogen_hjson_header(
    name = "otp_ctrl_regs",
    srcs = [
        "//hw:ip/otp_ctrl/data/otp_ctrl.hjson",
    ],
)

autogen_hjson_header(
    name = "rv_timer_regs",
    srcs = [
        "//hw:ip/rv_timer/data/rv_timer.hjson",
    ],
)

autogen_hjson_header(
    name = "spi_device_regs",
    srcs = [
        "//hw:ip/spi_device/data/spi_device.hjson",
    ],
)

autogen_hjson_header(
    name = "sram_ctrl_regs",
    srcs = [
        "//hw:ip/sram_ctrl/data/sram_ctrl.hjson",
    ],
)

autogen_hjson_header(
    name = "uart_regs",
    srcs = [
        "//hw:ip/uart/data/uart.hjson",
    ],
)

autogen_hjson_header(
    name = "usbdev_regs",
    srcs = [
        "//hw:ip/usbdev/data/usbdev.hjson",
    ],
)

autogen_hjson_header(
    name = "alert_handler_regs",
    srcs = [
        "//hw/top_earlgrey:ip/alert_handler/data/autogen/alert_handler.hjson",
    ],
)

autogen_hjson_header(
    name = "clkmgr_regs",
    srcs = [
        "//hw/top_earlgrey:ip/clkmgr/data/autogen/clkmgr.hjson",
    ],
)

autogen_hjson_header(
    name = "flash_ctrl_regs",
    srcs = [
        "//hw/top_earlgrey:ip/flash_ctrl/data/autogen/flash_ctrl.hjson",
    ],
)

autogen_hjson_header(
    name = "pinmux_regs",
    srcs = [
        "//hw/top_earlgrey:ip/pinmux/data/autogen/pinmux.hjson",
    ],
)

autogen_hjson_header(
    name = "pwrmgr_regs",
    srcs = [
        "//hw/top_earlgrey:ip/pwrmgr/data/autogen/pwrmgr.hjson",
    ],
)

autogen_hjson_header(
    name = "rstmgr_regs",
    srcs = [
        "//hw/top_earlgrey:ip/rstmgr/data/autogen/rstmgr.hjson",
    ],
)

autogen_hjson_header(
    name = "rv_plic_regs",
    srcs = [
        "//hw/top_earlgrey:ip/rv_plic/data/autogen/rv_plic.hjson",
    ],
)

otp_image(
    name = "otp_image_verilator",
    src = "//hw:ip/otp_ctrl/data/otp_ctrl_img_rma.hjson",
    deps = [
        "//hw:ip/otp_ctrl/data/otp_ctrl_mmap.hjson",
        "//hw:ip/lc_ctrl/data/lc_ctrl_state.hjson",
    ],
)
