// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class mbx_base_test extends cip_base_test #(
    .CFG_T(mbx_env_cfg),
    .ENV_T(mbx_env)
  );

  `uvm_component_utils(mbx_base_test)
  `uvm_component_new

  // the base class dv_base_test creates the following instances:
  // mbx_env_cfg: cfg
  // mbx_env:     env

  // the base class also looks up UVM_TEST_SEQ plusarg to create and run that seq in
  // the run_phase; as such, nothing more needs to be done

endclass : mbx_base_test
