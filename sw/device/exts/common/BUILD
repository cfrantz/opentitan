package(default_visibility = ["//visibility:public"])
load("//rules:opentitan.bzl", "OPENTITAN_CPU")

cc_library(
    name = "common",
    copts = [
        "-nostdlib",
        "-ffreestanding",
    ],
    srcs = [
        "ibex_interrupt_vectors.S",
        "flash_crt.S",
    ],
    linkopts = [
        "-T $(location flash_link.ld)",
    ],
    deps = [
        "flash_link.ld",
        "//sw/device:info_sections",
        "//hw/top_earlgrey/sw/autogen:linker_script",
    ],
    target_compatible_with = [OPENTITAN_CPU],
)
