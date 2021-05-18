load("@rules_rust//rust:defs.bzl", "rust_binary")
load("//third_party/cargo:crates.bzl", "all_crate_deps")

package(default_visibility = ["//visibility:public"])

rust_binary(
    name = "opentitantool",
    srcs = [
        "src/main.rs",
        "src/backend/verilator.rs",
        "src/backend/mod.rs",
        "src/command/hello.rs",
        "src/command/console.rs",
        "src/command/mod.rs",
    ],
    proc_macro_deps = [
        "//sw/host/opentitantool/opentitantool_derive",
    ],
    deps = [
        "//sw/host/opentitanlib",
    ] + all_crate_deps(),
)
