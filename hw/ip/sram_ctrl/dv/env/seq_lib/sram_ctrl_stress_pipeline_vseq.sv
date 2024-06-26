// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class sram_ctrl_stress_pipeline_vseq extends sram_ctrl_multiple_keys_vseq;

  `uvm_object_utils(sram_ctrl_stress_pipeline_vseq)
  `uvm_object_new

  // Since we now perform multiple accesses to each address, lower the total num_ops
  // to prevent simulations taking forever
  constraint num_ops_c {
    num_ops dist {
      [1 : 1000] :/ 1,
      [1001 : 2500] :/ 6,
      [2501 : 4000] :/ 2,
      [4001 : 5000] :/ 1
    };
  }

  // Reduce iteration as stress_pipeline runs many operations in one iteration
  constraint num_trans_c {
    num_trans inside {[5:10]};
  }

  virtual task pre_start();

    stress_pipeline = 1'b1;

    super.pre_start();

  endtask

endclass
