// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Security countermeasures testplan extracted from the IP Hjson using reggen.
//
// This testplan is auto-generated only the first time it is created. This is
// because this testplan needs to be hand-editable. It is possible that these
// testpoints can go out of date if the spec is updated with new
// countermeasures. When `reggen` is invoked when this testplan already exists,
// It checks if the list of testpoints is up-to-date and enforces the user to
// make further manual updates.
//
// These countermeasures and their descriptions can be found here:
// .../${module_instance_name}/data/${module_instance_name}.hjson
//
// It is possible that the testing of some of these countermeasures may already
// be covered as a testpoint in a different testplan. This duplication is ok -
// the test would have likely already been developed. We simply map those tests
// to the testpoints below using the `tests` key.
//
// Please ensure that this testplan is imported in:
// .../${module_instance_name}/data/${module_instance_name}_testplan.hjson
{
  testpoints: [
    {
      name: sec_cm_bus_integrity
      desc: "Verify the countermeasure(s) BUS.INTEGRITY."
      stage: V2S
      tests: []
    }
    {
      name: sec_cm_scramble_key_sideload
      desc: "Verify the countermeasure(s) SCRAMBLE.KEY.SIDELOAD."
      stage: V2S
      tests: []
    }
    {
      name: sec_cm_core_data_reg_sw_sca
      desc: "Verify the countermeasure(s) CORE.DATA_REG_SW.SCA."
      stage: V2S
      tests: []
    }
    {
      name: sec_cm_pc_ctrl_flow_consistency
      desc: "Verify the countermeasure(s) PC.CTRL_FLOW.CONSISTENCY."
      stage: V2S
      tests: []
    }
    {
      name: sec_cm_ctrl_flow_unpredictable
      desc: "Verify the countermeasure(s) CTRL_FLOW.UNPREDICTABLE."
      stage: V2S
      tests: []
    }
    {
      name: sec_cm_data_reg_sw_integrity
      desc: "Verify the countermeasure(s) DATA_REG_SW.INTEGRITY."
      stage: V2S
      tests: []
    }
    {
      name: sec_cm_data_reg_sw_glitch_detect
      desc: "Verify the countermeasure(s) DATA_REG_SW.GLITCH_DETECT."
      stage: V2S
      tests: []
    }
    {
      name: sec_cm_logic_shadow
      desc: "Verify the countermeasure(s) LOGIC.SHADOW."
      stage: V2S
      tests: []
    }
    {
      name: sec_cm_fetch_ctrl_lc_gated
      desc: "Verify the countermeasure(s) FETCH.CTRL.LC_GATED."
      stage: V2S
      tests: []
    }
    {
      name: sec_cm_exception_ctrl_flow_local_esc
      desc: "Verify the countermeasure(s) EXCEPTION.CTRL_FLOW.LOCAL_ESC."
      stage: V2S
      tests: []
    }
    {
      name: sec_cm_exception_ctrl_flow_global_esc
      desc: "Verify the countermeasure(s) EXCEPTION.CTRL_FLOW.GLOBAL_ESC."
      stage: V2S
      tests: []
    }
    {
      name: sec_cm_icache_mem_scramble
      desc: "Verify the countermeasure(s) ICACHE.MEM.SCRAMBLE."
      stage: V2S
      tests: []
    }
    {
      name: sec_cm_icache_mem_integrity
      desc: "Verify the countermeasure(s) ICACHE.MEM.INTEGRITY."
      stage: V2S
      tests: []
    }
  ]
}
