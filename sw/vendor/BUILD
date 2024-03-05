# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

package(default_visibility = ["//visibility:public"])

exports_files(glob(["veri-titan/gen/*.s"]))

cc_library(
    name = "cryptoc_sha256",
    srcs = ["cryptoc/sha256.c"],
    hdrs = [
        "cryptoc/include/cryptoc/hash-internal.h",
        "cryptoc/include/cryptoc/sha256.h",
    ],
    strip_include_prefix = "cryptoc/include",
)

cc_library(
    name = "cryptoc",
    copts = [
        "-Wno-error=implicit-int-conversion",
        "-Wno-error=sign-conversion",
    ],
    srcs = glob(
        ["cryptoc/*.c"],
        exclude=[
            "cryptoc/sha512.c",
            "cryptoc/sha384.c",
            "cryptoc/*_unittest.c",
        ]),
    hdrs = glob(["cryptoc/include/cryptoc/*.h"]),
    strip_include_prefix = "cryptoc/include",
)
