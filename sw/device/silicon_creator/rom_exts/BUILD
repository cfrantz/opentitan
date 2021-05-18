load("//rules:autogen.bzl", "manifest_header")
package(default_visibility = ["//visibility:public"])

manifest_header(
    name = "manifest",
    srcs = [
        "manifest.h.tpl",
        "manifest.hjson",
    ],
)

cc_library(
    name = "rom_ext_manifest_parser",
    hdrs = ["rom_ext_manifest_parser.h"],
    srcs = ["rom_ext_manifest_parser.c"],
    deps = [
        ":manifest",
        "//sw/device/lib/base",
        "//hw/top_earlgrey/sw/autogen:top_earlgrey",
    ],
)

