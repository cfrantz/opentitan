package(default_visibility = ["//visibility:public"])

cc_library(
    name = "base",
    hdrs = [
        "bitfield.h",
        "csr.h",
        "csr_registers.h",
        "hardened.h",
        "macros.h",
        "memory.h",
        "mmio.h",
        "stdasm.h",
    ],
    srcs = [
        "bitfield.c",
        "memory.c",
    ],
)

cc_library(
    name = "mmio",
    srcs = [
        "mmio.c",
    ],
    deps = [":base"],
)

filegroup(
    name = "mmio_src",
    srcs = ["mmio.c"],
)
