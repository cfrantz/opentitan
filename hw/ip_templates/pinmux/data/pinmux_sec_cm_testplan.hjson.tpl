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
// .../pinmux/data/pinmux.hjson
//
// It is possible that the testing of some of these countermeasures may already
// be covered as a testpoint in a different testplan. This duplication is ok -
// the test would have likely already been developed. We simply map those tests
// to the testpoints below using the `tests` key.
//
// Please ensure that this testplan is imported in:
// .../pinmux/data/pinmux_testplan.hjson
{
  testpoints: [
    {
      name: sec_cm_bus_integrity
      desc: "Verify the countermeasure(s) BUS.INTEGRITY."
      stage: V2S
      tests: []
    }
  % if enable_strap_sampling:
    {
      name: sec_cm_lc_dft_en_intersig_mubi
      desc: "Verify the countermeasure(s) LC_DFT_EN.INTERSIG.MUBI."
      stage: V2S
      tests: []
    }
    {
      name: sec_cm_lc_hw_debug_en_intersig_mubi
      desc: "Verify the countermeasure(s) LC_HW_DEBUG_EN.INTERSIG.MUBI."
      stage: V2S
      tests: []
    }
    {
      name: sec_cm_lc_check_byp_en_intersig_mubi
      desc: "Verify the countermeasure(s) LC_CHECK_BYP_EN.INTERSIG.MUBI."
      stage: V2S
      tests: []
    }
    {
      name: sec_cm_lc_escalate_en_intersig_mubi
      desc: "Verify the countermeasure(s) LC_ESCALATE_EN.INTERSIG.MUBI."
      stage: V2S
      tests: []
    }
    {
      name: sec_cm_pinmux_hw_debug_en_intersig_mubi
      desc: "Verify the countermeasure(s) PINMUX_HW_DEBUG_EN.INTERSIG.MUBI."
      stage: V2S
      tests: []
    }
    {
      name: sec_cm_tap_mux_lc_gated
      desc: "Verify the countermeasure(s) TAP.MUX.LC_GATED."
      stage: V2S
      tests: []
    }
  % endif
  ]
}
