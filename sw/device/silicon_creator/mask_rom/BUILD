package(default_visibility = ["//visibility:public"])
load("//rules:autogen.bzl", "chip_info")
load("//rules:opentitan.bzl", "OPENTITAN_CPU", "opentitan_binary")

opentitan_binary(
    name = "mask_rom",
    output_scrambled = True,
    linkopts = [
        "-nostartfiles",
        "-nostdlib",
    ],
    deps = [
        ":mask_rom_lib",
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
    name = "mask_rom_lib",
    copts = [
        "-nostdlib",
        "-ffreestanding",
    ],
    hdrs = ["mask_rom.h"],
    srcs = [
        "mask_rom_start.S",
        "mask_rom.c"
    ],
    linkopts = [
        "-T $(location mask_rom.ld)",
    ],
    deps = [
        "mask_rom.ld",
        ":linker_script_deps",
        ":chip_info",
        "//sw/device/lib/arch:device",
        "//sw/device/lib/base",
        "//sw/device/lib/crt",
        "//sw/device/lib:pinmux",
        "//sw/device/lib/runtime:hart",
        "//sw/device/lib/runtime:print",
        "//sw/device/silicon_creator/lib/drivers:hmac",
        "//sw/device/silicon_creator/lib/drivers:uart",
        "//sw/device/silicon_creator/rom_exts:rom_ext_manifest_parser",
        "//hw/top_earlgrey/sw/autogen:top_earlgrey",
    ],
    target_compatible_with = [OPENTITAN_CPU],
)

