load("@rules_rust//rust:defs.bzl", "rust_proc_macro")
load("//third_party/cargo:crates.bzl", "all_crate_deps")

package(default_visibility = ["//visibility:public"])

rust_proc_macro(
    name = "opentitantool_derive",
    srcs = ["src/lib.rs"],
    deps = [] + all_crate_deps(),
)
