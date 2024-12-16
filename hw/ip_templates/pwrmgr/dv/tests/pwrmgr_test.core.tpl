CAPI=2:
# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
name: ${instance_vlnv("lowrisc:dv:pwrmgr_test:0.1")}
description: "PWRMGR DV UVM test"
filesets:
  files_dv:
    depend:
      - ${instance_vlnv("lowrisc:dv:pwrmgr_env:0.1")}
    files:
      - pwrmgr_test_pkg.sv
      - pwrmgr_base_test.sv: {is_include_file: true}
    file_type: systemVerilogSource

targets:
  default:
    filesets:
      - files_dv