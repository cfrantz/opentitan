CAPI=2:
# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
name: ${instance_vlnv("lowrisc:dv:clkmgr_sim:0.1")}
description: "CLKMGR DV sim target"
filesets:
  files_rtl:
    depend:
      - ${instance_vlnv("lowrisc:ip:clkmgr")}

  files_dv:
    depend:
      - ${instance_vlnv("lowrisc:dv:clkmgr_test:0.1")}
      - ${instance_vlnv("lowrisc:dv:clkmgr_sva:0.1")}
    files:
      - tb.sv
      - cov/clkmgr_cov_bind.sv
    file_type: systemVerilogSource

targets:
  sim: &sim_target
    toplevel: tb
    filesets:
      - files_rtl
      - files_dv
    default_tool: vcs

  lint:
    <<: *sim_target