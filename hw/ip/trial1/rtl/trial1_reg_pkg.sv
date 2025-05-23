// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Register Package auto-generated by `reggen` containing data structure

package trial1_reg_pkg;

  // Address widths within the block
  parameter int BlockAw = 10;

  // Number of registers for every interface
  parameter int NumRegs = 20;

  ////////////////////////////
  // Typedefs for registers //
  ////////////////////////////

  typedef struct packed {
    logic [31:0] q;
  } trial1_reg2hw_rwtype0_reg_t;

  typedef struct packed {
    struct packed {
      logic [7:0]  q;
    } field15_8;
    struct packed {
      logic        q;
    } field4;
    struct packed {
      logic        q;
    } field1;
    struct packed {
      logic        q;
    } field0;
  } trial1_reg2hw_rwtype1_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } trial1_reg2hw_rwtype2_reg_t;

  typedef struct packed {
    struct packed {
      logic [15:0] q;
    } field1;
    struct packed {
      logic [15:0] q;
    } field0;
  } trial1_reg2hw_rwtype3_reg_t;

  typedef struct packed {
    struct packed {
      logic [15:0] q;
    } field1;
    struct packed {
      logic [15:0] q;
    } field0;
  } trial1_reg2hw_rwtype4_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } trial1_reg2hw_rotype0_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } trial1_reg2hw_w1ctype0_reg_t;

  typedef struct packed {
    struct packed {
      logic [15:0] q;
    } field1;
    struct packed {
      logic [15:0] q;
    } field0;
  } trial1_reg2hw_w1ctype1_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } trial1_reg2hw_w1ctype2_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } trial1_reg2hw_w1stype2_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } trial1_reg2hw_w0ctype2_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } trial1_reg2hw_r0w1ctype2_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } trial1_reg2hw_rctype0_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } trial1_reg2hw_wotype0_reg_t;

  typedef struct packed {
    struct packed {
      logic [3:0]  q;
    } field7;
    struct packed {
      logic [3:0]  q;
    } field6;
    struct packed {
      logic [3:0]  q;
    } field5;
    struct packed {
      logic [3:0]  q;
    } field4;
    struct packed {
      logic [3:0]  q;
    } field3;
    struct packed {
      logic [3:0]  q;
    } field2;
    struct packed {
      logic [3:0]  q;
    } field1;
    struct packed {
      logic [3:0]  q;
    } field0;
  } trial1_reg2hw_mixtype0_reg_t;

  typedef struct packed {
    logic [31:0] q;
    logic        qe;
  } trial1_reg2hw_rwtype5_reg_t;

  typedef struct packed {
    logic [31:0] q;
    logic        qe;
  } trial1_reg2hw_rwtype6_reg_t;

  typedef struct packed {
    logic [31:0] q;
  } trial1_reg2hw_rotype1_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } trial1_hw2reg_rwtype2_reg_t;

  typedef struct packed {
    struct packed {
      logic [15:0] d;
      logic        de;
    } field1;
    struct packed {
      logic [15:0] d;
      logic        de;
    } field0;
  } trial1_hw2reg_rwtype3_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } trial1_hw2reg_rotype0_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } trial1_hw2reg_w1ctype2_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } trial1_hw2reg_w1stype2_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } trial1_hw2reg_w0ctype2_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } trial1_hw2reg_r0w1ctype2_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } trial1_hw2reg_rctype0_reg_t;

  typedef struct packed {
    struct packed {
      logic [3:0]  d;
      logic        de;
    } field6;
    struct packed {
      logic [3:0]  d;
      logic        de;
    } field5;
    struct packed {
      logic [3:0]  d;
      logic        de;
    } field4;
    struct packed {
      logic [3:0]  d;
      logic        de;
    } field3;
    struct packed {
      logic [3:0]  d;
      logic        de;
    } field1;
  } trial1_hw2reg_mixtype0_reg_t;

  typedef struct packed {
    logic [31:0] d;
    logic        de;
  } trial1_hw2reg_rwtype5_reg_t;

  typedef struct packed {
    logic [31:0] d;
  } trial1_hw2reg_rwtype6_reg_t;

  typedef struct packed {
    logic [31:0] d;
  } trial1_hw2reg_rotype1_reg_t;

  // Register -> HW type
  typedef struct packed {
    trial1_reg2hw_rwtype0_reg_t rwtype0; // [556:525]
    trial1_reg2hw_rwtype1_reg_t rwtype1; // [524:514]
    trial1_reg2hw_rwtype2_reg_t rwtype2; // [513:482]
    trial1_reg2hw_rwtype3_reg_t rwtype3; // [481:450]
    trial1_reg2hw_rwtype4_reg_t rwtype4; // [449:418]
    trial1_reg2hw_rotype0_reg_t rotype0; // [417:386]
    trial1_reg2hw_w1ctype0_reg_t w1ctype0; // [385:354]
    trial1_reg2hw_w1ctype1_reg_t w1ctype1; // [353:322]
    trial1_reg2hw_w1ctype2_reg_t w1ctype2; // [321:290]
    trial1_reg2hw_w1stype2_reg_t w1stype2; // [289:258]
    trial1_reg2hw_w0ctype2_reg_t w0ctype2; // [257:226]
    trial1_reg2hw_r0w1ctype2_reg_t r0w1ctype2; // [225:194]
    trial1_reg2hw_rctype0_reg_t rctype0; // [193:162]
    trial1_reg2hw_wotype0_reg_t wotype0; // [161:130]
    trial1_reg2hw_mixtype0_reg_t mixtype0; // [129:98]
    trial1_reg2hw_rwtype5_reg_t rwtype5; // [97:65]
    trial1_reg2hw_rwtype6_reg_t rwtype6; // [64:32]
    trial1_reg2hw_rotype1_reg_t rotype1; // [31:0]
  } trial1_reg2hw_t;

  // HW -> register type
  typedef struct packed {
    trial1_hw2reg_rwtype2_reg_t rwtype2; // [386:354]
    trial1_hw2reg_rwtype3_reg_t rwtype3; // [353:320]
    trial1_hw2reg_rotype0_reg_t rotype0; // [319:287]
    trial1_hw2reg_w1ctype2_reg_t w1ctype2; // [286:254]
    trial1_hw2reg_w1stype2_reg_t w1stype2; // [253:221]
    trial1_hw2reg_w0ctype2_reg_t w0ctype2; // [220:188]
    trial1_hw2reg_r0w1ctype2_reg_t r0w1ctype2; // [187:155]
    trial1_hw2reg_rctype0_reg_t rctype0; // [154:122]
    trial1_hw2reg_mixtype0_reg_t mixtype0; // [121:97]
    trial1_hw2reg_rwtype5_reg_t rwtype5; // [96:64]
    trial1_hw2reg_rwtype6_reg_t rwtype6; // [63:32]
    trial1_hw2reg_rotype1_reg_t rotype1; // [31:0]
  } trial1_hw2reg_t;

  // Register offsets
  parameter logic [BlockAw-1:0] TRIAL1_RWTYPE0_OFFSET = 10'h 0;
  parameter logic [BlockAw-1:0] TRIAL1_RWTYPE1_OFFSET = 10'h 4;
  parameter logic [BlockAw-1:0] TRIAL1_RWTYPE2_OFFSET = 10'h 8;
  parameter logic [BlockAw-1:0] TRIAL1_RWTYPE3_OFFSET = 10'h c;
  parameter logic [BlockAw-1:0] TRIAL1_RWTYPE4_OFFSET = 10'h 200;
  parameter logic [BlockAw-1:0] TRIAL1_ROTYPE0_OFFSET = 10'h 204;
  parameter logic [BlockAw-1:0] TRIAL1_W1CTYPE0_OFFSET = 10'h 208;
  parameter logic [BlockAw-1:0] TRIAL1_W1CTYPE1_OFFSET = 10'h 20c;
  parameter logic [BlockAw-1:0] TRIAL1_W1CTYPE2_OFFSET = 10'h 210;
  parameter logic [BlockAw-1:0] TRIAL1_W1STYPE2_OFFSET = 10'h 214;
  parameter logic [BlockAw-1:0] TRIAL1_W0CTYPE2_OFFSET = 10'h 218;
  parameter logic [BlockAw-1:0] TRIAL1_R0W1CTYPE2_OFFSET = 10'h 21c;
  parameter logic [BlockAw-1:0] TRIAL1_RCTYPE0_OFFSET = 10'h 220;
  parameter logic [BlockAw-1:0] TRIAL1_WOTYPE0_OFFSET = 10'h 224;
  parameter logic [BlockAw-1:0] TRIAL1_MIXTYPE0_OFFSET = 10'h 228;
  parameter logic [BlockAw-1:0] TRIAL1_RWTYPE5_OFFSET = 10'h 22c;
  parameter logic [BlockAw-1:0] TRIAL1_RWTYPE6_OFFSET = 10'h 230;
  parameter logic [BlockAw-1:0] TRIAL1_ROTYPE1_OFFSET = 10'h 234;
  parameter logic [BlockAw-1:0] TRIAL1_ROTYPE2_OFFSET = 10'h 238;
  parameter logic [BlockAw-1:0] TRIAL1_RWTYPE7_OFFSET = 10'h 23c;

  // Reset values for hwext registers and their fields
  parameter logic [31:0] TRIAL1_RWTYPE6_RESVAL = 32'h c8c8c8c8;
  parameter logic [31:0] TRIAL1_RWTYPE6_RWTYPE6_RESVAL = 32'h c8c8c8c8;
  parameter logic [31:0] TRIAL1_ROTYPE1_RESVAL = 32'h 66aa66aa;
  parameter logic [31:0] TRIAL1_ROTYPE1_ROTYPE1_RESVAL = 32'h 66aa66aa;

  // Register index
  typedef enum int {
    TRIAL1_RWTYPE0,
    TRIAL1_RWTYPE1,
    TRIAL1_RWTYPE2,
    TRIAL1_RWTYPE3,
    TRIAL1_RWTYPE4,
    TRIAL1_ROTYPE0,
    TRIAL1_W1CTYPE0,
    TRIAL1_W1CTYPE1,
    TRIAL1_W1CTYPE2,
    TRIAL1_W1STYPE2,
    TRIAL1_W0CTYPE2,
    TRIAL1_R0W1CTYPE2,
    TRIAL1_RCTYPE0,
    TRIAL1_WOTYPE0,
    TRIAL1_MIXTYPE0,
    TRIAL1_RWTYPE5,
    TRIAL1_RWTYPE6,
    TRIAL1_ROTYPE1,
    TRIAL1_ROTYPE2,
    TRIAL1_RWTYPE7
  } trial1_id_e;

  // Register width information to check illegal writes
  parameter logic [3:0] TRIAL1_PERMIT [20] = '{
    4'b 1111, // index[ 0] TRIAL1_RWTYPE0
    4'b 0011, // index[ 1] TRIAL1_RWTYPE1
    4'b 1111, // index[ 2] TRIAL1_RWTYPE2
    4'b 1111, // index[ 3] TRIAL1_RWTYPE3
    4'b 1111, // index[ 4] TRIAL1_RWTYPE4
    4'b 1111, // index[ 5] TRIAL1_ROTYPE0
    4'b 1111, // index[ 6] TRIAL1_W1CTYPE0
    4'b 1111, // index[ 7] TRIAL1_W1CTYPE1
    4'b 1111, // index[ 8] TRIAL1_W1CTYPE2
    4'b 1111, // index[ 9] TRIAL1_W1STYPE2
    4'b 1111, // index[10] TRIAL1_W0CTYPE2
    4'b 1111, // index[11] TRIAL1_R0W1CTYPE2
    4'b 1111, // index[12] TRIAL1_RCTYPE0
    4'b 1111, // index[13] TRIAL1_WOTYPE0
    4'b 1111, // index[14] TRIAL1_MIXTYPE0
    4'b 1111, // index[15] TRIAL1_RWTYPE5
    4'b 1111, // index[16] TRIAL1_RWTYPE6
    4'b 1111, // index[17] TRIAL1_ROTYPE1
    4'b 1111, // index[18] TRIAL1_ROTYPE2
    4'b 1111  // index[19] TRIAL1_RWTYPE7
  };

endpackage
