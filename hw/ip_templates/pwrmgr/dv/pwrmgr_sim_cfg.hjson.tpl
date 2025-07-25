// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
{
  // Name of the sim cfg - typically same as the name of the DUT.
  name: pwrmgr

  // Top level dut name (sv module).
  dut: pwrmgr

  // Top level testbench name (sv module).
  tb: tb

  // Simulator used to sign off this block
  tool: vcs

  // Fusesoc core file used for building the file list.
  fusesoc_core: ${instance_vlnv("lowrisc:dv:pwrmgr_sim:0.1")}

  // Testplan hjson file.
  testplan: "{self_dir}/../data/pwrmgr_testplan.hjson"

  // Import additional common sim cfg files.
  import_cfgs: [// Project wide common sim cfg file
                "{proj_root}/hw/dv/tools/dvsim/common_sim_cfg.hjson",
                // Common CIP test lists
                "{proj_root}/hw/dv/tools/dvsim/tests/csr_tests.hjson",
                "{proj_root}/hw/dv/tools/dvsim/tests/intr_test.hjson",
                "{proj_root}/hw/dv/tools/dvsim/tests/stress_tests.hjson",
                "{proj_root}/hw/dv/tools/dvsim/tests/sec_cm_tests.hjson",
                "{proj_root}/hw/dv/tools/dvsim/tests/tl_access_tests.hjson"]

  // Exclusion files
  vcs_cov_excl_files: ["{self_dir}/cov/pwrmgr_cov_manual_excl.el"]

  // Overrides
  overrides: [
    // Handle generated coverage exclusion.
    {
      name: default_vcs_cov_cfg_file
      value: "-cm_hier {dv_root}/tools/vcs/cover.cfg+{dv_root}/tools/vcs/common_cov_excl.cfg+{self_dir}/cov/pwrmgr_tgl_excl.cfg"
    }
  ]

  // Add additional tops for simulation.
  sim_tops: ["pwrmgr_bind",
             "pwrmgr_cov_bind",
             "pwrmgr_unit_only_bind",
             "sec_cm_prim_count_bind",
             "sec_cm_prim_sparse_fsm_flop_bind",
             "sec_cm_prim_onehot_check_bind"]

  // Default iterations for all tests - each test entry can override this.
  reseed: 50

  // Default UVM test and seq class name.
  uvm_test: pwrmgr_base_test
  uvm_test_seq: pwrmgr_base_vseq

  // Enable cdc instrumentation.
  run_opts: ["+cdc_instrumentation_enabled=1"]

  // List of test specifications.
  tests: [
    {
      name: pwrmgr_smoke
      uvm_test_seq: pwrmgr_smoke_vseq
      run_opts: ["+test_timeout_ns=1000000"]
    }
    {
      name: pwrmgr_reset
      uvm_test_seq: pwrmgr_reset_vseq
      run_opts: ["+test_timeout_ns=1000000"]
    }
    {
      name: pwrmgr_lowpower_wakeup_race
      uvm_test_seq: pwrmgr_lowpower_wakeup_race_vseq
      run_opts: ["+test_timeout_ns=1000000"]
    }
    {
      name: pwrmgr_wakeup
      uvm_test_seq: pwrmgr_wakeup_vseq
      run_opts: ["+test_timeout_ns=1000000"]
    }
    {
      name: pwrmgr_wakeup_reset
      uvm_test_seq: pwrmgr_wakeup_reset_vseq
      run_opts: ["+test_timeout_ns=1000000"]
    }
    {
      name: pwrmgr_aborted_low_power
      uvm_test_seq: pwrmgr_aborted_low_power_vseq
    }
    {
      name: pwrmgr_sec_cm_lc_ctrl_intersig_mubi
      uvm_test_seq: pwrmgr_repeat_wakeup_reset_vseq
      run_opts: ["+test_timeout_ns=3000000", "+pwrmgr_mubi_mode=PwrmgrMubiLcCtrl"]
    }
    {
      name: pwrmgr_sec_cm_rstmgr_intersig_mubi
      uvm_test_seq: pwrmgr_sw_reset_vseq
      run_opts: ["+test_timeout_ns=1000000"]
    }
    {
      name: pwrmgr_esc_clk_rst_malfunc
      uvm_test_seq: pwrmgr_esc_clk_rst_malfunc_vseq
      run_opts: ["+test_timeout_ns=1000000"]
    }
    {
      name: pwrmgr_sec_cm_ctrl_config_regwen
      uvm_test_seq: pwrmgr_sec_cm_ctrl_config_regwen_vseq
      run_opts: ["+test_timeout_ns=50000000"]
    }
    {
      name: pwrmgr_global_esc
      uvm_test_seq: pwrmgr_global_esc_vseq
      run_opts: ["+test_timeout_ns=1000000000"]
    }
    {
      name: pwrmgr_escalation_timeout
      uvm_test_seq: pwrmgr_escalation_timeout_vseq
    }
    {
      name: pwrmgr_glitch
      uvm_test_seq: pwrmgr_glitch_vseq
      run_opts: ["+test_timeout_ns=1000000"]
    }
    {
      name: pwrmgr_disable_rom_integrity_check
      uvm_test_seq: pwrmgr_disable_rom_integrity_check_vseq
      run_opts: ["+test_timeout_ns=1000000"]
    }
    {
      name: pwrmgr_reset_invalid
      uvm_test_seq: pwrmgr_reset_invalid_vseq
      run_opts: ["+test_timeout_ns=1000000"]
    }
    {
      name: pwrmgr_lowpower_invalid
      uvm_test_seq: pwrmgr_lowpower_invalid_vseq
      run_opts: ["+test_timeout_ns=1000000"]
    }
  ]

  // List of regressions.
  regressions: [
    {
      name: smoke
      tests: ["pwrmgr_smoke"]
    }
  ]
}
