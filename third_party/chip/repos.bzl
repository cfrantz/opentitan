# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

load("//rules:repo.bzl", "http_archive_or_local")

def chip_repos(
        earlgrey_es = None,
    ):
    http_archive_or_local(
        name = "earlgrey_es_bitstreams",
        local = earlgrey_es,
        sha256 = "",
        strip_prefix = "",
        url = "",
    )
