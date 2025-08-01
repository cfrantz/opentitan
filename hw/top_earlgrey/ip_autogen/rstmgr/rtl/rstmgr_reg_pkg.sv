// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Register Package auto-generated by `reggen` containing data structure

package rstmgr_reg_pkg;

  // Param list
  parameter int RdWidth = 32;
  parameter int IdxWidth = 4;
  parameter int NumHwResets = 5;
  parameter int NumSwResets = 8;
  parameter int NumTotalResets = 8;
  parameter int NumAlerts = 2;

  // Address widths within the block
  parameter int BlockAw = 7;

  // Number of registers for every interface
  parameter int NumRegs = 28;

  // Alert indices
  typedef enum int {
    AlertFatalFaultIdx = 0,
    AlertFatalCnstyFaultIdx = 1
  } rstmgr_alert_idx_t;

  ////////////////////////////
  // Typedefs for registers //
  ////////////////////////////

  typedef struct packed {
    struct packed {
      logic        q;
      logic        qe;
    } fatal_cnsty_fault;
    struct packed {
      logic        q;
      logic        qe;
    } fatal_fault;
  } rstmgr_reg2hw_alert_test_reg_t;

  typedef struct packed {
    logic [3:0]  q;
  } rstmgr_reg2hw_reset_req_reg_t;

  typedef struct packed {
    struct packed {
      logic [4:0]  q;
    } hw_req;
    struct packed {
      logic        q;
    } sw_reset;
  } rstmgr_reg2hw_reset_info_reg_t;

  typedef struct packed {
    struct packed {
      logic [3:0]  q;
    } index;
    struct packed {
      logic        q;
    } en;
  } rstmgr_reg2hw_alert_info_ctrl_reg_t;

  typedef struct packed {
    struct packed {
      logic [3:0]  q;
    } index;
    struct packed {
      logic        q;
    } en;
  } rstmgr_reg2hw_cpu_info_ctrl_reg_t;

  typedef struct packed {
    logic        q;
  } rstmgr_reg2hw_sw_rst_ctrl_n_mreg_t;

  typedef struct packed {
    struct packed {
      logic        q;
    } fsm_err;
    struct packed {
      logic        q;
    } reset_consistency_err;
    struct packed {
      logic        q;
    } reg_intg_err;
  } rstmgr_reg2hw_err_code_reg_t;

  typedef struct packed {
    logic [3:0]  d;
    logic        de;
  } rstmgr_hw2reg_reset_req_reg_t;

  typedef struct packed {
    struct packed {
      logic [4:0]  d;
      logic        de;
    } hw_req;
    struct packed {
      logic        d;
      logic        de;
    } sw_reset;
    struct packed {
      logic        d;
      logic        de;
    } low_power_exit;
  } rstmgr_hw2reg_reset_info_reg_t;

  typedef struct packed {
    struct packed {
      logic        d;
      logic        de;
    } en;
  } rstmgr_hw2reg_alert_info_ctrl_reg_t;

  typedef struct packed {
    logic [3:0]  d;
  } rstmgr_hw2reg_alert_info_attr_reg_t;

  typedef struct packed {
    logic [31:0] d;
  } rstmgr_hw2reg_alert_info_reg_t;

  typedef struct packed {
    struct packed {
      logic        d;
      logic        de;
    } en;
  } rstmgr_hw2reg_cpu_info_ctrl_reg_t;

  typedef struct packed {
    logic [3:0]  d;
  } rstmgr_hw2reg_cpu_info_attr_reg_t;

  typedef struct packed {
    logic [31:0] d;
  } rstmgr_hw2reg_cpu_info_reg_t;

  typedef struct packed {
    struct packed {
      logic        d;
      logic        de;
    } fsm_err;
    struct packed {
      logic        d;
      logic        de;
    } reset_consistency_err;
    struct packed {
      logic        d;
      logic        de;
    } reg_intg_err;
  } rstmgr_hw2reg_err_code_reg_t;

  // Register -> HW type
  typedef struct packed {
    rstmgr_reg2hw_alert_test_reg_t alert_test; // [34:31]
    rstmgr_reg2hw_reset_req_reg_t reset_req; // [30:27]
    rstmgr_reg2hw_reset_info_reg_t reset_info; // [26:21]
    rstmgr_reg2hw_alert_info_ctrl_reg_t alert_info_ctrl; // [20:16]
    rstmgr_reg2hw_cpu_info_ctrl_reg_t cpu_info_ctrl; // [15:11]
    rstmgr_reg2hw_sw_rst_ctrl_n_mreg_t [7:0] sw_rst_ctrl_n; // [10:3]
    rstmgr_reg2hw_err_code_reg_t err_code; // [2:0]
  } rstmgr_reg2hw_t;

  // HW -> register type
  typedef struct packed {
    rstmgr_hw2reg_reset_req_reg_t reset_req; // [96:92]
    rstmgr_hw2reg_reset_info_reg_t reset_info; // [91:82]
    rstmgr_hw2reg_alert_info_ctrl_reg_t alert_info_ctrl; // [81:80]
    rstmgr_hw2reg_alert_info_attr_reg_t alert_info_attr; // [79:76]
    rstmgr_hw2reg_alert_info_reg_t alert_info; // [75:44]
    rstmgr_hw2reg_cpu_info_ctrl_reg_t cpu_info_ctrl; // [43:42]
    rstmgr_hw2reg_cpu_info_attr_reg_t cpu_info_attr; // [41:38]
    rstmgr_hw2reg_cpu_info_reg_t cpu_info; // [37:6]
    rstmgr_hw2reg_err_code_reg_t err_code; // [5:0]
  } rstmgr_hw2reg_t;

  // Register offsets
  parameter logic [BlockAw-1:0] RSTMGR_ALERT_TEST_OFFSET = 7'h 0;
  parameter logic [BlockAw-1:0] RSTMGR_RESET_REQ_OFFSET = 7'h 4;
  parameter logic [BlockAw-1:0] RSTMGR_RESET_INFO_OFFSET = 7'h 8;
  parameter logic [BlockAw-1:0] RSTMGR_ALERT_REGWEN_OFFSET = 7'h c;
  parameter logic [BlockAw-1:0] RSTMGR_ALERT_INFO_CTRL_OFFSET = 7'h 10;
  parameter logic [BlockAw-1:0] RSTMGR_ALERT_INFO_ATTR_OFFSET = 7'h 14;
  parameter logic [BlockAw-1:0] RSTMGR_ALERT_INFO_OFFSET = 7'h 18;
  parameter logic [BlockAw-1:0] RSTMGR_CPU_REGWEN_OFFSET = 7'h 1c;
  parameter logic [BlockAw-1:0] RSTMGR_CPU_INFO_CTRL_OFFSET = 7'h 20;
  parameter logic [BlockAw-1:0] RSTMGR_CPU_INFO_ATTR_OFFSET = 7'h 24;
  parameter logic [BlockAw-1:0] RSTMGR_CPU_INFO_OFFSET = 7'h 28;
  parameter logic [BlockAw-1:0] RSTMGR_SW_RST_REGWEN_0_OFFSET = 7'h 2c;
  parameter logic [BlockAw-1:0] RSTMGR_SW_RST_REGWEN_1_OFFSET = 7'h 30;
  parameter logic [BlockAw-1:0] RSTMGR_SW_RST_REGWEN_2_OFFSET = 7'h 34;
  parameter logic [BlockAw-1:0] RSTMGR_SW_RST_REGWEN_3_OFFSET = 7'h 38;
  parameter logic [BlockAw-1:0] RSTMGR_SW_RST_REGWEN_4_OFFSET = 7'h 3c;
  parameter logic [BlockAw-1:0] RSTMGR_SW_RST_REGWEN_5_OFFSET = 7'h 40;
  parameter logic [BlockAw-1:0] RSTMGR_SW_RST_REGWEN_6_OFFSET = 7'h 44;
  parameter logic [BlockAw-1:0] RSTMGR_SW_RST_REGWEN_7_OFFSET = 7'h 48;
  parameter logic [BlockAw-1:0] RSTMGR_SW_RST_CTRL_N_0_OFFSET = 7'h 4c;
  parameter logic [BlockAw-1:0] RSTMGR_SW_RST_CTRL_N_1_OFFSET = 7'h 50;
  parameter logic [BlockAw-1:0] RSTMGR_SW_RST_CTRL_N_2_OFFSET = 7'h 54;
  parameter logic [BlockAw-1:0] RSTMGR_SW_RST_CTRL_N_3_OFFSET = 7'h 58;
  parameter logic [BlockAw-1:0] RSTMGR_SW_RST_CTRL_N_4_OFFSET = 7'h 5c;
  parameter logic [BlockAw-1:0] RSTMGR_SW_RST_CTRL_N_5_OFFSET = 7'h 60;
  parameter logic [BlockAw-1:0] RSTMGR_SW_RST_CTRL_N_6_OFFSET = 7'h 64;
  parameter logic [BlockAw-1:0] RSTMGR_SW_RST_CTRL_N_7_OFFSET = 7'h 68;
  parameter logic [BlockAw-1:0] RSTMGR_ERR_CODE_OFFSET = 7'h 6c;

  // Reset values for hwext registers and their fields
  parameter logic [1:0] RSTMGR_ALERT_TEST_RESVAL = 2'h 0;
  parameter logic [0:0] RSTMGR_ALERT_TEST_FATAL_FAULT_RESVAL = 1'h 0;
  parameter logic [0:0] RSTMGR_ALERT_TEST_FATAL_CNSTY_FAULT_RESVAL = 1'h 0;
  parameter logic [3:0] RSTMGR_ALERT_INFO_ATTR_RESVAL = 4'h 0;
  parameter logic [3:0] RSTMGR_ALERT_INFO_ATTR_CNT_AVAIL_RESVAL = 4'h 0;
  parameter logic [31:0] RSTMGR_ALERT_INFO_RESVAL = 32'h 0;
  parameter logic [31:0] RSTMGR_ALERT_INFO_VALUE_RESVAL = 32'h 0;
  parameter logic [3:0] RSTMGR_CPU_INFO_ATTR_RESVAL = 4'h 0;
  parameter logic [3:0] RSTMGR_CPU_INFO_ATTR_CNT_AVAIL_RESVAL = 4'h 0;
  parameter logic [31:0] RSTMGR_CPU_INFO_RESVAL = 32'h 0;
  parameter logic [31:0] RSTMGR_CPU_INFO_VALUE_RESVAL = 32'h 0;

  // Register index
  typedef enum int {
    RSTMGR_ALERT_TEST,
    RSTMGR_RESET_REQ,
    RSTMGR_RESET_INFO,
    RSTMGR_ALERT_REGWEN,
    RSTMGR_ALERT_INFO_CTRL,
    RSTMGR_ALERT_INFO_ATTR,
    RSTMGR_ALERT_INFO,
    RSTMGR_CPU_REGWEN,
    RSTMGR_CPU_INFO_CTRL,
    RSTMGR_CPU_INFO_ATTR,
    RSTMGR_CPU_INFO,
    RSTMGR_SW_RST_REGWEN_0,
    RSTMGR_SW_RST_REGWEN_1,
    RSTMGR_SW_RST_REGWEN_2,
    RSTMGR_SW_RST_REGWEN_3,
    RSTMGR_SW_RST_REGWEN_4,
    RSTMGR_SW_RST_REGWEN_5,
    RSTMGR_SW_RST_REGWEN_6,
    RSTMGR_SW_RST_REGWEN_7,
    RSTMGR_SW_RST_CTRL_N_0,
    RSTMGR_SW_RST_CTRL_N_1,
    RSTMGR_SW_RST_CTRL_N_2,
    RSTMGR_SW_RST_CTRL_N_3,
    RSTMGR_SW_RST_CTRL_N_4,
    RSTMGR_SW_RST_CTRL_N_5,
    RSTMGR_SW_RST_CTRL_N_6,
    RSTMGR_SW_RST_CTRL_N_7,
    RSTMGR_ERR_CODE
  } rstmgr_id_e;

  // Register width information to check illegal writes
  parameter logic [3:0] RSTMGR_PERMIT [28] = '{
    4'b 0001, // index[ 0] RSTMGR_ALERT_TEST
    4'b 0001, // index[ 1] RSTMGR_RESET_REQ
    4'b 0001, // index[ 2] RSTMGR_RESET_INFO
    4'b 0001, // index[ 3] RSTMGR_ALERT_REGWEN
    4'b 0001, // index[ 4] RSTMGR_ALERT_INFO_CTRL
    4'b 0001, // index[ 5] RSTMGR_ALERT_INFO_ATTR
    4'b 1111, // index[ 6] RSTMGR_ALERT_INFO
    4'b 0001, // index[ 7] RSTMGR_CPU_REGWEN
    4'b 0001, // index[ 8] RSTMGR_CPU_INFO_CTRL
    4'b 0001, // index[ 9] RSTMGR_CPU_INFO_ATTR
    4'b 1111, // index[10] RSTMGR_CPU_INFO
    4'b 0001, // index[11] RSTMGR_SW_RST_REGWEN_0
    4'b 0001, // index[12] RSTMGR_SW_RST_REGWEN_1
    4'b 0001, // index[13] RSTMGR_SW_RST_REGWEN_2
    4'b 0001, // index[14] RSTMGR_SW_RST_REGWEN_3
    4'b 0001, // index[15] RSTMGR_SW_RST_REGWEN_4
    4'b 0001, // index[16] RSTMGR_SW_RST_REGWEN_5
    4'b 0001, // index[17] RSTMGR_SW_RST_REGWEN_6
    4'b 0001, // index[18] RSTMGR_SW_RST_REGWEN_7
    4'b 0001, // index[19] RSTMGR_SW_RST_CTRL_N_0
    4'b 0001, // index[20] RSTMGR_SW_RST_CTRL_N_1
    4'b 0001, // index[21] RSTMGR_SW_RST_CTRL_N_2
    4'b 0001, // index[22] RSTMGR_SW_RST_CTRL_N_3
    4'b 0001, // index[23] RSTMGR_SW_RST_CTRL_N_4
    4'b 0001, // index[24] RSTMGR_SW_RST_CTRL_N_5
    4'b 0001, // index[25] RSTMGR_SW_RST_CTRL_N_6
    4'b 0001, // index[26] RSTMGR_SW_RST_CTRL_N_7
    4'b 0001  // index[27] RSTMGR_ERR_CODE
  };

endpackage
