load("@rules_rust//rust:defs.bzl", "rust_library")
load("//third_party/cargo:crates.bzl", "all_crate_deps")

package(default_visibility = ["//visibility:public"])

rust_library(
    name = "opentitanlib",
    srcs = [
        "src/lib.rs",
        "src/io/spi.rs",
        "src/io/uart.rs",
        "src/io/gpio.rs",
        "src/io/mod.rs",
        "src/transport/mod.rs",
        "src/transport/verilator/mod.rs",
        "src/util/file.rs",
        "src/util/mod.rs",
    ],
    deps = [
    ] + all_crate_deps(),
)
