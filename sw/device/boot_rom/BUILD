package(default_visibility = ["//visibility:public"])
load("//rules:autogen.bzl", "chip_info")
load("//rules:opentitan.bzl", "OPENTITAN_CPU", "opentitan_binary")

opentitan_binary(
    name = "boot_rom",
    output_scrambled = True,
    linkopts = [
        "-nostartfiles",
        "-nostdlib",
    ],
    deps = [
        ":boot_rom_lib",
    ],
)

chip_info(
    name = "chip_info",
)

cc_library(
    name = "linker_script_deps",
    deps = [
        "//sw/device:info_sections",
        "//hw/top_earlgrey/sw/autogen:linker_script",
    ],
)

cc_library(
    name = "boot_rom_lib",
    copts = [
        "-nostdlib",
        "-ffreestanding",
    ],
    srcs = [
        "irq_vector.S",
        "rom_crt.S",
        "boot_rom.c",
    ],
    linkopts = [
        "-T $(location rom_link.ld)",
    ],
    deps = [
        ":bootstrap",
        ":chip_info",
        "rom_link.ld",
        ":linker_script_deps",
        "//:sram_ctrl_regs",
        "//:entropy_src_regs",
        "//:csrng_regs",
        "//:edn_regs",
        "//sw/device/lib/arch:device",
        "//sw/device/lib/base",
        "//sw/device/lib/base:mmio",
        "//sw/device/lib/crt",
        "//sw/device/lib/dif:dif_gpio",
        "//sw/device/lib/dif:dif_hmac",
        "//sw/device/lib:flash_ctrl",
        "//sw/device/lib:pinmux",
        "//sw/device/lib/runtime:hart",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/runtime:print",
        "//sw/device/lib/testing",
        "//hw/top_earlgrey/sw/autogen:top_earlgrey",
    ],
    target_compatible_with = [OPENTITAN_CPU],
)

cc_library(
    name = "bootstrap",
    hdrs = [
        "bootstrap.h",
        "spiflash_frame.h",
    ],
    srcs = [
        "bootstrap.c",
    ],
    deps = [
        "//sw/device/lib/arch:device",
        "//sw/device/lib/base",
        "//sw/device/lib/dif:dif_gpio",
        "//sw/device/lib/dif:dif_hmac",
        "//sw/device/lib/dif:dif_spi_device",
        "//sw/device/lib:flash_ctrl",
        "//sw/device/lib/runtime:hart",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/testing",
        "//hw/top_earlgrey/sw/autogen:top_earlgrey",
    ],
)
