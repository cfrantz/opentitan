// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`include "prim_assert.sv"

module dma
  import tlul_pkg::*;
  import dma_pkg::*;
  import dma_reg_pkg::*;
#(
  parameter logic [NumAlerts-1:0]           AlertAsyncOn              = {NumAlerts{1'b1}},
  // Number of cycles of differential skew to be tolerated on the alert signal
  parameter int unsigned                    AlertSkewCycles           = 1,
  parameter bit                             EnableDataIntgGen         = 1'b1,
  parameter bit                             EnableRspDataIntgCheck    = 1'b1,
  parameter logic [RsvdWidth-1:0]           TlUserRsvd                = '0,
  parameter logic [SYS_RACL_WIDTH-1:0]      SysRacl                   = '0,
  parameter int unsigned                    OtAgentId                 = 0,
  parameter bit                             EnableRacl                = 1'b0,
  parameter bit                             RaclErrorRsp              = EnableRacl,
  parameter top_racl_pkg::racl_policy_sel_t RaclPolicySelVec[NumRegs] = '{NumRegs{0}}
) (
  input logic                                       clk_i,
  input logic                                       rst_ni,
  input prim_mubi_pkg::mubi4_t                      scanmode_i,
  // DMA interrupts and incoming LSIO triggers
  output  logic                                     intr_dma_done_o,
  output  logic                                     intr_dma_chunk_done_o,
  output  logic                                     intr_dma_error_o,
  input   lsio_trigger_t                            lsio_trigger_i,
  // Alerts
  input  prim_alert_pkg::alert_rx_t [NumAlerts-1:0] alert_rx_i,
  output prim_alert_pkg::alert_tx_t [NumAlerts-1:0] alert_tx_o,
  // RACL interface
  input  top_racl_pkg::racl_policy_vec_t            racl_policies_i,
  output top_racl_pkg::racl_error_log_t             racl_error_o,
  // Device port
  input   tlul_pkg::tl_h2d_t                        tl_d_i,
  output  tlul_pkg::tl_d2h_t                        tl_d_o,
  // Facing CTN
  input   tlul_pkg::tl_d2h_t                        ctn_tl_d2h_i,
  output  tlul_pkg::tl_h2d_t                        ctn_tl_h2d_o,
  // Host port
  input   tlul_pkg::tl_d2h_t                        host_tl_h_i,
  output  tlul_pkg::tl_h2d_t                        host_tl_h_o,
  // System port
  input  dma_pkg::sys_rsp_t                         sys_i,
  output dma_pkg::sys_req_t                         sys_o
);
  import prim_mubi_pkg::*;
  import prim_sha2_pkg::*;

  dma_reg2hw_t reg2hw;
  dma_hw2reg_t hw2reg;

  localparam int unsigned TRANSFER_BYTES_WIDTH    = $bits(reg2hw.total_data_size.q);
  localparam int unsigned INTR_CLEAR_SOURCES_WIDTH = $clog2(NumIntClearSources);
  localparam int unsigned NR_SHA_DIGEST_ELEMENTS  = 16;

  // Flopped bus for SYS interface
  dma_pkg::sys_req_t sys_req_d;
  dma_pkg::sys_rsp_t sys_resp_q;

  // Signals for both TL interfaces
  logic                       dma_host_tlul_req_valid,    dma_ctn_tlul_req_valid;
  logic [top_pkg::TL_AW-1:0]  dma_host_tlul_req_addr,     dma_ctn_tlul_req_addr;
  logic                       dma_host_tlul_req_we,       dma_ctn_tlul_req_we;
  logic [top_pkg::TL_DW-1:0]  dma_host_tlul_req_wdata,    dma_ctn_tlul_req_wdata;
  logic [top_pkg::TL_DBW-1:0] dma_host_tlul_req_be,       dma_ctn_tlul_req_be;
  logic                       dma_host_tlul_gnt,          dma_ctn_tlul_gnt;
  logic                       dma_host_tlul_rsp_valid,    dma_ctn_tlul_rsp_valid;
  logic [top_pkg::TL_DW-1:0]  dma_host_tlul_rsp_data,     dma_ctn_tlul_rsp_data;
  logic                       dma_host_tlul_rsp_err,      dma_ctn_tlul_rsp_err;
  logic                       dma_host_tlul_rsp_intg_err, dma_ctn_tlul_rsp_intg_err;

  logic                       dma_host_write, dma_host_read, dma_host_clear_intr;
  logic                       dma_ctn_write,  dma_ctn_read,  dma_ctn_clear_intr;
  logic                       dma_sys_write,  dma_sys_read;

  logic                       capture_return_data;
  logic [top_pkg::TL_DW-1:0]  read_return_data_q, read_return_data_d, dma_rsp_data;
  logic [SYS_ADDR_WIDTH-1:0]  new_src_addr, new_dst_addr;

  logic dma_state_error;
  // SEC_CM: FSM.SPARSE
  dma_ctrl_state_e ctrl_state_q, ctrl_state_d;
  logic set_error_code, clear_go, clear_status, clear_sha_status, chunk_done;

  logic [INTR_CLEAR_SOURCES_WIDTH-1:0] clear_index_d, clear_index_q;
  logic                                clear_index_en, intr_clear_tlul_rsp_valid;
  logic                                intr_clear_tlul_gnt, intr_clear_tlul_rsp_error;

  logic [DmaErrLast-1:0] next_error;

  // Read request grant
  logic read_gnt;
  // Read response
  logic read_rsp_valid;
  // Read error occurred
  //   (Note: in use `read_rsp_error` must be qualified with `read_rsp_valid`)
  logic read_rsp_error;

  // Write request grant
  logic write_gnt;
  // Write response
  logic write_rsp_valid;
  // Write error occurred
  //   (Note: in use `write_rsp_error` must be qualified with `write_rsp_valid`)
  logic write_rsp_error;

  logic cfg_abort_en;
  assign cfg_abort_en = reg2hw.control.abort.q;

  logic cfg_handshake_en;

  logic [SYS_METADATA_WIDTH-1:0] src_metadata;
  assign src_metadata = SYS_METADATA_WIDTH'(1'b1) << OtAgentId;

  // Decode scan mode enable MuBi signal.
  logic scanmode;
  assign scanmode = mubi4_test_true_strict(scanmode_i);

  logic sw_reg_wr, sw_reg_wr1, sw_reg_wr2;
  assign sw_reg_wr = reg2hw.control.go.qe;
  prim_flop #(
    .Width(1)
  ) aff_reg_wr1 (
    .clk_i ( clk_i      ),
    .rst_ni( rst_ni     ),
    .d_i   ( sw_reg_wr  ),
    .q_o   ( sw_reg_wr1 )
  );
  prim_flop #(
    .Width(1)
  ) aff_reg_wr2 (
    .clk_i ( clk_i      ),
    .rst_ni( rst_ni     ),
    .d_i   ( sw_reg_wr1 ),
    .q_o   ( sw_reg_wr2 )
  );

  // Stretch out CR writes to make sure new value can propagate through logic
  logic sw_reg_wr_extended;
  assign sw_reg_wr_extended = sw_reg_wr || sw_reg_wr1 || sw_reg_wr2;

  logic gated_clk_en, gated_clk;
  assign gated_clk_en = reg2hw.control.go.q       ||
                        (ctrl_state_q != DmaIdle) ||
                        sw_reg_wr_extended;

  prim_clock_gating #(
    .FpgaBufGlobal(1'b0) // Instantiate a local instead of a global clock buffer on FPGAs
  ) dma_clk_gate (
    .clk_i    ( clk_i        ),
    .en_i     ( gated_clk_en ),
    .test_en_i( scanmode     ),     ///< Test On to turn off the clock gating during test
    .clk_o    ( gated_clk    )
  );

  logic reg_intg_error;
  // SEC_CM: BUS.INTEGRITY
  // SEC_CM: RANGE.CONFIG.REGWEN_MUBI
  dma_reg_top #(
    .EnableRacl       ( EnableRacl       ),
    .RaclErrorRsp     ( RaclErrorRsp     ),
    .RaclPolicySelVec ( RaclPolicySelVec )
  ) u_dma_reg (
    .clk_i     ( clk_i          ),
    .rst_ni    ( rst_ni         ),
    .tl_i      ( tl_d_i         ),
    .tl_o      ( tl_d_o         ),
    .reg2hw,
    .hw2reg,
    .racl_policies_i,
    .racl_error_o,
    .intg_err_o( reg_intg_error )
  );

  // Alerts
  logic [NumAlerts-1:0] alert_test, alerts;
  assign alert_test = {reg2hw.alert_test.q & reg2hw.alert_test.qe};
  assign alerts[0]  = reg_intg_error              ||
                      dma_host_tlul_rsp_intg_err  ||
                      dma_ctn_tlul_rsp_intg_err   ||
                      dma_state_error;

  for (genvar i = 0; i < NumAlerts; i++) begin : gen_alert_tx
    prim_alert_sender #(
      .AsyncOn(AlertAsyncOn[i]),
      .SkewCycles(AlertSkewCycles),
      .IsFatal(1'b1)
    ) u_prim_alert_sender (
      .clk_i,
      .rst_ni,
      .alert_test_i (alert_test[i]),
      .alert_req_i  (alerts[i]),
      .alert_ack_o  (),
      .alert_state_o(),
      .alert_rx_i   (alert_rx_i[i]),
      .alert_tx_o   (alert_tx_o[i])
    );
  end

  // Adapter from the DMA to Host
  tlul_adapter_host #(
    .MAX_REQS(NUM_MAX_OUTSTANDING_REQS),
    .EnableDataIntgGen(EnableDataIntgGen),
    .EnableRspDataIntgCheck(EnableRspDataIntgCheck)
  ) u_dma_host_tlul_host (
    .clk_i          ( gated_clk                        ),
    .rst_ni         ( rst_ni                           ),
    // do not make a request unless there is room for the response
    .req_i          ( dma_host_tlul_req_valid          ),
    .gnt_o          ( dma_host_tlul_gnt                ),
    .addr_i         ( dma_host_tlul_req_addr           ),
    .we_i           ( dma_host_tlul_req_we             ),
    .wdata_i        ( dma_host_tlul_req_wdata          ),
    .wdata_intg_i   ( TL_A_USER_DEFAULT.data_intg      ),
    .be_i           ( dma_host_tlul_req_be             ),
    .instr_type_i   ( MuBi4False                       ),
    .user_rsvd_i    ( TlUserRsvd                       ),
    .valid_o        ( dma_host_tlul_rsp_valid          ),
    .rdata_o        ( dma_host_tlul_rsp_data           ),
    .rdata_intg_o   (                                  ),
    .err_o          ( dma_host_tlul_rsp_err            ),
    .intg_err_o     ( dma_host_tlul_rsp_intg_err       ),
    .tl_o           ( host_tl_h_o                      ),
    .tl_i           ( host_tl_h_i                      )
  );

  // Adapter from the DMA to the CTN
  tlul_adapter_host #(
    .MAX_REQS(NUM_MAX_OUTSTANDING_REQS),
    .EnableDataIntgGen(EnableDataIntgGen),
    .EnableRspDataIntgCheck(EnableRspDataIntgCheck)
  ) u_dma_ctn_tlul_host (
    .clk_i          ( gated_clk                        ),
    .rst_ni         ( rst_ni                           ),
    // do not make a request unless there is room for the response
    .req_i          ( dma_ctn_tlul_req_valid           ),
    .gnt_o          ( dma_ctn_tlul_gnt                 ),
    .addr_i         ( dma_ctn_tlul_req_addr            ),
    .we_i           ( dma_ctn_tlul_req_we              ),
    .wdata_i        ( dma_ctn_tlul_req_wdata           ),
    .wdata_intg_i   ( TL_A_USER_DEFAULT.data_intg      ),
    .be_i           ( dma_ctn_tlul_req_be              ),
    .instr_type_i   ( MuBi4False                       ),
    .user_rsvd_i    ( TlUserRsvd                       ),
    .valid_o        ( dma_ctn_tlul_rsp_valid           ),
    .rdata_o        ( dma_ctn_tlul_rsp_data            ),
    .rdata_intg_o   (                                  ),
    .err_o          ( dma_ctn_tlul_rsp_err             ),
    .intg_err_o     ( dma_ctn_tlul_rsp_intg_err        ),
    .tl_o           ( ctn_tl_h2d_o                     ),
    .tl_i           ( ctn_tl_d2h_i                     )
  );

  // Masking incoming handshake triggers with their enables
  lsio_trigger_t lsio_trigger;
  always_comb begin
    lsio_trigger = '0;

    for (int i = 0; i < NumIntClearSources; i++) begin
      lsio_trigger[i] = lsio_trigger_i[i] && reg2hw.handshake_intr_enable.q[i];
    end
  end

  // During the active DMA operation, most of the DMA registers are locked with a hardware-
  // controlled REGWEN. However, this mechanism is not possible for all registers. For example,
  // some registers already have a different REGWEN attached (range locking) or the CONTROL
  // register, which needs to be partly writable. To lock those registers, we capture their value
  // during the start of the operation and, later on, only use the captured value in the state
  // machine. The captured state is stored in control_q.
  control_state_t control_d, control_q;
  logic           capture_state;

  // Fiddle out control bits into captured state
  always_comb begin
    control_d.opcode                     = opcode_e'(reg2hw.control.opcode.q);
    control_d.cfg_handshake_en           = reg2hw.control.hardware_handshake_enable.q;
    control_d.cfg_digest_swap            = reg2hw.control.digest_swap.q;
    control_d.range_valid                = reg2hw.range_valid.q;
    control_d.enabled_memory_range_base  = reg2hw.enabled_memory_range_base.q;
    control_d.enabled_memory_range_limit = reg2hw.enabled_memory_range_limit.q;
  end

  prim_flop_en #(
    .Width($bits(control_state_t))
  ) u_opcode (
    .clk_i  ( gated_clk     ),
    .rst_ni ( rst_ni        ),
    .en_i   ( capture_state ),
    .d_i    ( control_d     ),
    .q_o    ( control_q     )
  );

  `PRIM_FLOP_SPARSE_FSM(aff_ctrl_state_q, ctrl_state_d, ctrl_state_q, dma_ctrl_state_e, DmaIdle,
                        gated_clk, rst_ni)

  logic [TRANSFER_BYTES_WIDTH-1:0] transfer_byte_q, transfer_byte_d;
  logic [TRANSFER_BYTES_WIDTH-1:0] transfer_remaining_bytes;
  logic [TRANSFER_BYTES_WIDTH-1:0] chunk_remaining_bytes;
  logic [TRANSFER_BYTES_WIDTH-1:0] remaining_bytes;
  logic                            capture_transfer_byte;
  prim_flop_en #(
    .Width(TRANSFER_BYTES_WIDTH)
  ) aff_transfer_byte (
    .clk_i  ( gated_clk             ),
    .rst_ni ( rst_ni                ),
    .en_i   ( capture_transfer_byte ),
    .d_i    ( transfer_byte_d       ),
    .q_o    ( transfer_byte_q       )
  );

  logic [TRANSFER_BYTES_WIDTH-1:0] chunk_byte_q, chunk_byte_d;
  logic                            capture_chunk_byte;
  prim_flop_en #(
    .Width(TRANSFER_BYTES_WIDTH)
  ) aff_chunk_byte (
    .clk_i  ( gated_clk          ),
    .rst_ni ( rst_ni             ),
    .en_i   ( capture_chunk_byte ),
    .d_i    ( chunk_byte_d       ),
    .q_o    ( chunk_byte_q       )
  );

  logic       capture_transfer_width;
  logic [2:0] transfer_width_q, transfer_width_d;
  prim_flop_en #(
    .Width(3)
  ) aff_transfer_width (
    .clk_i ( gated_clk              ),
    .rst_ni( rst_ni                 ),
    .en_i  ( capture_transfer_width ),
    .d_i   ( transfer_width_d       ),
    .q_o   ( transfer_width_q       )
  );

  logic                      capture_addr;
  logic [SYS_ADDR_WIDTH-1:0] src_addr_q, src_addr_d;
  logic [SYS_ADDR_WIDTH-1:0] dst_addr_q, dst_addr_d;
  prim_flop_en #(
    .Width(SYS_ADDR_WIDTH)
  ) aff_src_addr (
    .clk_i ( gated_clk    ),
    .rst_ni( rst_ni       ),
    .en_i  ( capture_addr ),
    .d_i   ( src_addr_d   ),
    .q_o   ( src_addr_q   )
  );

  prim_flop_en #(
    .Width(SYS_ADDR_WIDTH)
  ) aff_dst_addr (
    .clk_i ( gated_clk    ),
    .rst_ni( rst_ni       ),
    .en_i  ( capture_addr ),
    .d_i   ( dst_addr_d   ),
    .q_o   ( dst_addr_q   )
  );

  logic                       capture_be;
  logic [top_pkg::TL_DBW-1:0] req_src_be_q, req_src_be_d;
  logic [top_pkg::TL_DBW-1:0] req_dst_be_q, req_dst_be_d;
  prim_flop_en #(
    .Width(top_pkg::TL_DBW)
  ) aff_req_src_be (
    .clk_i ( gated_clk    ),
    .rst_ni( rst_ni       ),
    .en_i  ( capture_be   ),
    .d_i   ( req_src_be_d ),
    .q_o   ( req_src_be_q )
  );

  prim_flop_en #(
    .Width(top_pkg::TL_DBW)
  ) aff_req_dst_be (
    .clk_i ( gated_clk    ),
    .rst_ni( rst_ni       ),
    .en_i  ( capture_be   ),
    .d_i   ( req_dst_be_d ),
    .q_o   ( req_dst_be_q )
  );

  prim_flop_en #(
    .Width(INTR_CLEAR_SOURCES_WIDTH)
  ) u_clear_index (
    .clk_i ( gated_clk      ),
    .rst_ni( rst_ni         ),
    .en_i  ( clear_index_en ),
    .d_i   ( clear_index_d  ),
    .q_o   ( clear_index_q  )
  );

  logic use_inline_hashing;
  logic sha2_hash_start, sha2_hash_process;
  logic sha2_valid, sha2_ready, sha2_digest_set;
  sha_fifo32_t sha2_data;
  digest_mode_e sha2_mode;
  sha_word64_t [7:0] sha2_digest;

  assign use_inline_hashing = control_q.opcode inside {OpcSha256,  OpcSha384, OpcSha512};
  // When reaching DmaShaFinalize, we are consuming data and start computing the digest value
  assign sha2_hash_process = (ctrl_state_q == DmaShaFinalize);

  logic sha2_consumed_d, sha2_consumed_q;
  prim_flop #(
    .Width(1)
  ) u_sha2_consumed (
    .clk_i ( gated_clk       ),
    .rst_ni( rst_ni          ),
    .d_i   ( sha2_consumed_d ),
    .q_o   ( sha2_consumed_q )
  );

  logic sha2_hash_done;
  logic sha2_hash_done_d, sha2_hash_done_q;
  prim_flop #(
    .Width(1)
  ) u_sha2_hash_done (
    .clk_i ( gated_clk        ),
    .rst_ni( rst_ni           ),
    .d_i   ( sha2_hash_done_d ),
    .q_o   ( sha2_hash_done_q )
  );

  // The SHA engine requires the message length in bits
  logic [63:0] sha2_message_len_bits;
  assign sha2_message_len_bits = reg2hw.total_data_size.q << 3;

  // Translate the DMA opcode to the SHA2 digest mode
  always_comb begin
    unique case (control_q.opcode)
      OpcSha256: sha2_mode = SHA2_256;
      OpcSha384: sha2_mode = SHA2_384;
      OpcSha512: sha2_mode = SHA2_512;
      default:   sha2_mode = SHA2_None;
    endcase
  end

  // SHA2 engine for inline hashing operations
  prim_sha2_32 #(.MultimodeEn(1)) u_sha2 (
    .clk_i              ( clk_i                 ),
    .rst_ni             ( rst_ni                ),
    .wipe_secret_i      ( 1'b0                  ),
    .wipe_v_i           ( 32'b0                 ),
    .fifo_rvalid_i      ( sha2_valid            ),
    .fifo_rdata_i       ( sha2_data             ),
    .fifo_rready_o      ( sha2_ready            ),
    .sha_en_i           ( 1'b1                  ),
    .hash_start_i       ( sha2_hash_start       ),
    .hash_stop_i        ( 1'b0                  ),
    .hash_continue_i    ( 1'b0                  ),
    .digest_mode_i      ( sha2_mode             ),
    .hash_process_i     ( sha2_hash_process     ),
    .hash_done_o        ( sha2_hash_done        ),
    .message_length_i   ( sha2_message_len_bits ),
    .digest_i           ( '0                    ),
    .digest_we_i        ( '0                    ),
    .digest_o           ( sha2_digest           ),
    .digest_on_blk_o    (                       ),
    .hash_running_o     (                       ),
    .idle_o             (                       )
  );

  // Fiddle ASIDs out for better readability during the rest of the code
  logic [ASID_WIDTH-1:0] src_asid, dst_asid;
  assign src_asid = reg2hw.addr_space_id.src_asid.q;
  assign dst_asid = reg2hw.addr_space_id.dst_asid.q;

  // Note: bus signals shall be asserted only when configured and active, to ensure
  // that address and - especially - data are not leaked to other buses.

  // Host interface to OT Internal address space
  always_comb begin
    dma_host_write = (ctrl_state_q == DmaSendWrite) & (dst_asid == OtInternalAddr);
    dma_host_read  = (ctrl_state_q == DmaSendRead)  & (src_asid == OtInternalAddr);

    dma_host_tlul_req_valid = dma_host_write | dma_host_read | dma_host_clear_intr;
    // TL-UL 4B aligned
    dma_host_tlul_req_addr  = dma_host_write ? {dst_addr_q[top_pkg::TL_AW-1:2], 2'b0} :
                             (dma_host_read  ? {src_addr_q[top_pkg::TL_AW-1:2], 2'b0} :
                        (dma_host_clear_intr ? reg2hw.intr_src_addr[clear_index_q].q : 'b0));
    dma_host_tlul_req_we    = dma_host_write | dma_host_clear_intr;
    dma_host_tlul_req_wdata = dma_host_write ? read_return_data_q :
                        (dma_host_clear_intr ? reg2hw.intr_src_wr_val[clear_index_q].q : 'b0);
    dma_host_tlul_req_be    = dma_host_write ? req_dst_be_q :
                             (dma_host_read  ? req_src_be_q
                                             : {top_pkg::TL_DBW{dma_host_clear_intr}});
  end

  // Host interface to SoC CTN address space
  always_comb begin
    dma_ctn_write = (ctrl_state_q == DmaSendWrite) & (dst_asid == SocControlAddr);
    dma_ctn_read  = (ctrl_state_q == DmaSendRead)  & (src_asid == SocControlAddr);

    dma_ctn_tlul_req_valid = dma_ctn_write | dma_ctn_read | dma_ctn_clear_intr;
    // TL-UL 4B aligned
    dma_ctn_tlul_req_addr  = dma_ctn_write ? {dst_addr_q[top_pkg::TL_AW-1:2], 2'b0} :
                            (dma_ctn_read  ? {src_addr_q[top_pkg::TL_AW-1:2], 2'b0} :
                       (dma_ctn_clear_intr ? reg2hw.intr_src_addr[clear_index_q].q : 'b0));
    dma_ctn_tlul_req_we    = dma_ctn_write | dma_ctn_clear_intr;
    dma_ctn_tlul_req_wdata = dma_ctn_write ? read_return_data_q :
                       (dma_ctn_clear_intr ? reg2hw.intr_src_wr_val[clear_index_q].q : 'b0);
    dma_ctn_tlul_req_be    = dma_ctn_write ? req_dst_be_q :
                            (dma_ctn_read  ? req_src_be_q : {top_pkg::TL_DBW{dma_ctn_clear_intr}});
  end

  // Host interface to SoC SYS address space
  always_comb begin
    dma_sys_write = (ctrl_state_q == DmaSendWrite) & (dst_asid == SocSystemAddr);
    dma_sys_read  = (ctrl_state_q == DmaSendRead)  & (src_asid  == SocSystemAddr);

    sys_req_d.vld_vec     [SysCmdWrite] = dma_sys_write;
    sys_req_d.metadata_vec[SysCmdWrite] = src_metadata;
    sys_req_d.opcode_vec  [SysCmdWrite] = SysOpcWrite;
    sys_req_d.iova_vec    [SysCmdWrite] = dma_sys_write ?
                                         {dst_addr_q[(SYS_ADDR_WIDTH-1):2], 2'b0} : 'b0;
    sys_req_d.racl_vec    [SysCmdWrite] = SysRacl[SysOpcWrite-1:0];

    sys_req_d.write_data = {SYS_DATA_WIDTH{dma_sys_write}} & read_return_data_q;
    sys_req_d.write_be   = {SYS_DATA_BYTEWIDTH{dma_sys_write}} & req_dst_be_q;

    sys_req_d.vld_vec     [SysCmdRead] = dma_sys_read;
    sys_req_d.metadata_vec[SysCmdRead] = src_metadata;
    sys_req_d.opcode_vec  [SysCmdRead] = SysOpcRead;
    sys_req_d.iova_vec    [SysCmdRead] = dma_sys_read ?
                                         {src_addr_q[(SYS_ADDR_WIDTH-1):2], 2'b0} : 'b0;
    sys_req_d.racl_vec    [SysCmdRead] = SysRacl[SYS_RACL_WIDTH-1:0];
    sys_req_d.read_be                  = req_src_be_q;
  end

  // Write response muxing
  always_comb begin
    unique case (dst_asid)
      OtInternalAddr: begin
        // Write request grant
        write_gnt       = dma_host_tlul_gnt;
        // Write response
        write_rsp_valid = dma_host_tlul_rsp_valid;
        // Write error occurred
        write_rsp_error = dma_host_tlul_rsp_err;
      end
      SocSystemAddr: begin
        write_gnt       = 1'b1;  // No requirement to wait
        write_rsp_valid = sys_resp_q.grant_vec[SysCmdWrite] | sys_resp_q.error_vld;
        write_rsp_error = sys_resp_q.error_vld;
      end
      // SocControlAddr is handled here
      //   (other ASID values prevented in configuration validation).
      default: begin
        write_gnt       = dma_ctn_tlul_gnt;
        write_rsp_valid = dma_ctn_tlul_rsp_valid;
        write_rsp_error = dma_ctn_tlul_rsp_err;
      end
    endcase
  end

  // Read response muxing
  always_comb begin
    unique case (src_asid)
      OtInternalAddr: begin
        // Read request grant
        read_gnt       = dma_host_tlul_gnt;
        // Read response
        read_rsp_valid = dma_host_tlul_rsp_valid;
        // Read error occurred
        read_rsp_error = dma_host_tlul_rsp_err;
      end
      SocSystemAddr: begin
        read_gnt       = 1'b1;  // No requirement to wait
        read_rsp_valid = sys_resp_q.read_data_vld;
        read_rsp_error = sys_resp_q.error_vld;
      end
      // SocControlAddr is handled here
      //   (other ASID values prevented in configuration validation).
      default: begin
        read_gnt       = dma_ctn_tlul_gnt;
        read_rsp_valid = dma_ctn_tlul_rsp_valid;
        read_rsp_error = dma_ctn_tlul_rsp_err;
      end
    endcase
  end

  always_comb begin
    ctrl_state_d = ctrl_state_q;

    capture_transfer_byte  = 1'b0;
    transfer_byte_d        = transfer_byte_q;
    capture_chunk_byte     = 1'b0;
    chunk_byte_d           = chunk_byte_q;
    capture_transfer_width = 1'b0;
    transfer_width_d       = '0;
    capture_return_data    = 1'b0;
    capture_state          = 1'b0;

    next_error   = '0;
    capture_addr = 1'b0;
    src_addr_d   = '0;
    dst_addr_d   = '0;

    capture_be   = '0;
    req_src_be_d = '0;
    req_dst_be_d = '0;

    dma_host_clear_intr = 1'b0;
    dma_ctn_clear_intr = 1'b0;
    clear_index_d  = '0;
    clear_index_en = '0;

    clear_go       = 1'b0;
    chunk_done     = 1'b0;

    // Mux the TL-UL grant and response signals depending on the selected bus interface
    intr_clear_tlul_gnt       = reg2hw.clear_intr_bus.q[clear_index_q] ? dma_host_tlul_gnt :
                                                                         dma_ctn_tlul_gnt;
    intr_clear_tlul_rsp_valid = reg2hw.clear_intr_bus.q[clear_index_q] ? dma_host_tlul_rsp_valid :
                                                                         dma_ctn_tlul_rsp_valid;
    intr_clear_tlul_rsp_error = reg2hw.clear_intr_bus.q[clear_index_q] ? dma_host_tlul_rsp_err :
                                                                         dma_ctn_tlul_rsp_err;
    dma_state_error = 1'b0;

    sha2_hash_start      = 1'b0;
    sha2_valid           = 1'b0;
    sha2_digest_set      = 1'b0;
    sha2_consumed_d      = sha2_consumed_q;

    // Make `SHA2 Done` sticky to not miss a single-cycle done event during any outstanding writes
    if (ctrl_state_q == DmaIdle) begin
      sha2_hash_done_d = 1'b0;
    end else begin
      sha2_hash_done_d = sha2_hash_done_q | sha2_hash_done;
    end

    // Default assignments for the muxed config signals for the idle state
    cfg_handshake_en = control_q.cfg_handshake_en;

    // Abort has the highest priority in the state machine. In all cases, if the abort is raised,
    // the DMA is reset to the idle state. This includes the error state and the default state,
    // which should never be reached during normal operation. The abort condition has precedence
    // over any outstanding TL-UL transaction.
    if (cfg_abort_en) begin
      ctrl_state_d = DmaIdle;
      clear_go     = 1'b1;
    end else begin
      unique case (ctrl_state_q)
        DmaIdle: begin
          chunk_byte_d       = '0;
          capture_chunk_byte = 1'b1;

          // In DmaIdle we need to determine if we are really idling or we are doing a roundtrip
          // via idle. If we are really idling, we need to take the config from the register
          // interface; otherwise we need to take the captured data.
          if (!reg2hw.status.busy.q) begin
            // We are idling
            cfg_handshake_en = reg2hw.control.hardware_handshake_enable.q;
          end
          // else, we are doing a roundtrip, and signaling is covered by the default assignment

          // Wait for `go` bit to be set to proceed with data movement
          if (reg2hw.control.go.q || reg2hw.status.busy.q) begin
            // Clear the transferred bytes only on the very first iteration
            if (reg2hw.control.initial_transfer.q && !reg2hw.status.busy.q) begin
              transfer_byte_d       = '0;
              capture_transfer_byte = 1'b1;
              // Capture unlocked state when starting the transfer.
              capture_state = 1'b1;
            end
            // if not handshake start transfer
            if (!cfg_handshake_en) begin
              ctrl_state_d = DmaAddrSetup;
            end else if (cfg_handshake_en && |lsio_trigger) begin
              // if handshake wait for interrupt
              if (|reg2hw.clear_intr_src.q) begin
                clear_index_en = 1'b1;
                clear_index_d  = '0;
                ctrl_state_d   = DmaClearIntrSrc;
              end else begin
                ctrl_state_d = DmaAddrSetup;
              end
            end
          end
        end

        DmaClearIntrSrc: begin
          // Clear the interrupt by writing
          if (reg2hw.clear_intr_src.q[clear_index_q]) begin
            // Send 'clear interrupt' write to the appropriate bus
            dma_host_clear_intr = reg2hw.clear_intr_bus.q[clear_index_q];
            dma_ctn_clear_intr = !reg2hw.clear_intr_bus.q[clear_index_q];

            if (intr_clear_tlul_gnt) begin
              ctrl_state_d = DmaWaitIntrSrcResponse;
            end

            // Writes also get a resp valid, but no data.
            // Need to wait for this to not overrun TL-UL adapter
            // The response might come immediately
            if (intr_clear_tlul_rsp_valid) begin
              if (intr_clear_tlul_rsp_error) begin
                next_error[DmaBusErr] = 1'b1;
                ctrl_state_d = DmaError;
              end else if (32'(clear_index_q) >= (NumIntClearSources - 1)) begin
                ctrl_state_d = DmaAddrSetup;  // Proceed now we've handled all
              end
            end
          end else begin
            // Do nothing if no clearing requested
            clear_index_en = 1'b1;
            clear_index_d  = clear_index_q + INTR_CLEAR_SOURCES_WIDTH'(1'b1);

            if (32'(clear_index_q) >= (NumIntClearSources - 1)) begin
              ctrl_state_d = DmaAddrSetup;
            end
          end
        end

        DmaWaitIntrSrcResponse: begin
          // Writes also get a resp valid, but no data.
          // Need to wait for this to not overrun TL-UL adapter
          if (intr_clear_tlul_rsp_valid) begin
            if (intr_clear_tlul_rsp_error) begin
              next_error[DmaBusErr] = 1'b1;
              ctrl_state_d = DmaError;
            end else if (32'(clear_index_q) < (NumIntClearSources - 1)) begin
              clear_index_en = 1'b1;
              clear_index_d  = clear_index_q + INTR_CLEAR_SOURCES_WIDTH'(1'b1);
              ctrl_state_d   = DmaClearIntrSrc;
            end else begin
              ctrl_state_d = DmaAddrSetup;
            end
          end
        end

        DmaAddrSetup: begin
          capture_transfer_width = 1'b1;
          capture_addr           = 1'b1;
          capture_be             = 1'b1;
          sha2_consumed_d        = 1'b0;

          // Convert the `transfer_width` encoding to bytes per transaction
          unique case (reg2hw.transfer_width.q)
            DmaXfer1BperTxn: transfer_width_d = 3'b001; // 1 byte
            DmaXfer2BperTxn: transfer_width_d = 3'b010; // 2 bytes
            DmaXfer4BperTxn: transfer_width_d = 3'b100; // 4 bytes
            // Value 3 is an invalid configuration value that leads to an error
            default: next_error[DmaSizeErr] = 1'b1;  // Invalid transfer_width
          endcase

          // Use start address on first byte of transaction
          if ((transfer_byte_q == '0) ||
              // or when in the fixed address mode
              reg2hw.src_config.increment.q == AddrNoIncrement ||
              // or when transferring the first byte of a chunk and in wrapped increment mode
              (chunk_byte_q == '0 && reg2hw.src_config.wrap.q == AddrWrapChunk)) begin
            src_addr_d = {reg2hw.src_addr_hi.q, reg2hw.src_addr_lo.q};
          end else begin
            // Advance from the previous transaction within this chunk
            src_addr_d = src_addr_q + SYS_ADDR_WIDTH'(transfer_width_d);
          end

          // Use start address on first byte of transaction
          if ((transfer_byte_q == '0) ||
              // or when in the fixed address mode
              reg2hw.dst_config.increment.q == AddrNoIncrement ||
              // or when transferring the first byte of a chunk and in wrapped increment mode
              (chunk_byte_q == '0 && reg2hw.dst_config.wrap.q == AddrWrapChunk)) begin
            dst_addr_d = {reg2hw.dst_addr_hi.q, reg2hw.dst_addr_lo.q};
          end else begin
            // Advance from the previous transaction within this chunk
            dst_addr_d = dst_addr_q + SYS_ADDR_WIDTH'(transfer_width_d);
          end

          unique case (transfer_width_d)
            3'b001: begin
              req_dst_be_d = top_pkg::TL_DBW'('b0001) << dst_addr_d[1:0];
              req_src_be_d = top_pkg::TL_DBW'('b0001) << src_addr_d[1:0];
            end
            3'b010: begin
              if (remaining_bytes >= TRANSFER_BYTES_WIDTH'(transfer_width_d)) begin
                req_dst_be_d = top_pkg::TL_DBW'('b0011) << dst_addr_d[1:0];
                req_src_be_d = top_pkg::TL_DBW'('b0011) << src_addr_d[1:0];
              end else begin
                req_dst_be_d = top_pkg::TL_DBW'('b0001) << dst_addr_d[1:0];
                req_src_be_d = top_pkg::TL_DBW'('b0001) << src_addr_d[1:0];
              end
            end
            3'b100: begin
              if (remaining_bytes >= TRANSFER_BYTES_WIDTH'(transfer_width_d)) begin
                req_dst_be_d = {top_pkg::TL_DBW{1'b1}};
              end else begin
                unique case (remaining_bytes)
                  TRANSFER_BYTES_WIDTH'('h1): req_dst_be_d = top_pkg::TL_DBW'('b0001);
                  TRANSFER_BYTES_WIDTH'('h2): req_dst_be_d = top_pkg::TL_DBW'('b0011);
                  TRANSFER_BYTES_WIDTH'('h3): req_dst_be_d = top_pkg::TL_DBW'('b0111);
                  default:                    req_dst_be_d = top_pkg::TL_DBW'('b1111);
                endcase
              end

              req_src_be_d = req_dst_be_d;  // in the case of 4B src should always = dst
            end
            default: begin
              req_dst_be_d = top_pkg::TL_DBW'('b0000);
              req_src_be_d = top_pkg::TL_DBW'('b0000);
            end
          endcase

          // Error checking. An invalid configuration triggers one or more errors
          // and does not start the DMA transfer
          if ((reg2hw.chunk_data_size.q == '0) ||         // No empty transactions
              (reg2hw.total_data_size.q == '0)) begin     // No empty transactions
            next_error[DmaSizeErr] = 1'b1;
          end

          if (!(control_q.opcode inside {OpcCopy, OpcSha256, OpcSha384, OpcSha512})) begin
            next_error[DmaOpcodeErr] = 1'b1;
          end

          // Inline hashing is only allowed for 32-bit transfer width
          if (use_inline_hashing) begin
            if (reg2hw.transfer_width.q != DmaXfer4BperTxn) begin
              next_error[DmaSizeErr] = 1'b1;
            end
          end

          // Ensure that ASIDs have valid values
          // SEC_CM: ASID.INTERSIG.MUBI
          if (!(src_asid inside {OtInternalAddr, SocControlAddr, SocSystemAddr})) begin
            next_error[DmaAsidErr] = 1'b1;
          end
          if (!(dst_asid inside {OtInternalAddr, SocControlAddr, SocSystemAddr})) begin
            next_error[DmaAsidErr] = 1'b1;
          end

          // Check the validity of the restricted DMA-enabled memory range
          // Note: both the base and the limit addresses are inclusive
          if (control_q.enabled_memory_range_limit < control_q.enabled_memory_range_base) begin
            next_error[DmaBaseLimitErr] = 1'b1;
          end

          // In 4-byte transfers, source and destination address must be 4-byte aligned
          if (reg2hw.transfer_width.q == DmaXfer4BperTxn && |reg2hw.src_addr_lo.q[1:0]) begin
            next_error[DmaSrcAddrErr] = 1'b1;
          end
          if (reg2hw.transfer_width.q == DmaXfer4BperTxn && |reg2hw.dst_addr_lo.q[1:0]) begin
            next_error[DmaDstAddrErr] = 1'b1;
          end

          // In 2-byte transfers, source and destination address must be 2-byte aligned
          if (reg2hw.transfer_width.q == DmaXfer2BperTxn && reg2hw.src_addr_lo.q[0]) begin
            next_error[DmaSrcAddrErr] = 1'b1;
          end
          if (reg2hw.transfer_width.q == DmaXfer2BperTxn &&
              reg2hw.dst_addr_lo.q[0]) begin
            next_error[DmaDstAddrErr] = 1'b1;
          end

          // If data from the SOC system bus or the control bus is transferred
          // to the OT internal memory, we must check if the destination address range falls into
          // the DMA enabled memory region.
          if ((src_asid inside {SocControlAddr, SocSystemAddr}) && (dst_asid == OtInternalAddr) &&
              // Out-of-bound check
              ((reg2hw.dst_addr_lo.q > control_q.enabled_memory_range_limit) ||
                (reg2hw.dst_addr_lo.q < control_q.enabled_memory_range_base) ||
                ((SYS_ADDR_WIDTH'(reg2hw.dst_addr_lo.q) +
                  SYS_ADDR_WIDTH'(reg2hw.chunk_data_size.q)) >
                  SYS_ADDR_WIDTH'(control_q.enabled_memory_range_limit)))) begin
            next_error[DmaDstAddrErr] = 1'b1;
          end

          // If data from the OT internal memory is transferred  to the SOC system bus or the
          // control bus, we must check if the source address range falls into the
          // DMA enabled memory region.
          if ((dst_asid inside {SocControlAddr, SocSystemAddr}) && (src_asid == OtInternalAddr) &&
                // Out-of-bound check
                ((reg2hw.src_addr_lo.q > control_q.enabled_memory_range_limit) ||
                (reg2hw.src_addr_lo.q < control_q.enabled_memory_range_base)   ||
                ((SYS_ADDR_WIDTH'(reg2hw.src_addr_lo.q) +
                  SYS_ADDR_WIDTH'(reg2hw.chunk_data_size.q)) >
                  SYS_ADDR_WIDTH'(control_q.enabled_memory_range_limit)))) begin
            next_error[DmaSrcAddrErr] = 1'b1;
          end

          // If the source ASID is the SOC control port or the OT internal port, we are accessing a
          // 32-bit address space. Thus the upper bits of the source address must be zero
          if ((src_asid inside {SocControlAddr, OtInternalAddr}) &&
              (|reg2hw.src_addr_hi.q)) begin
            next_error[DmaSrcAddrErr] = 1'b1;
          end

          // If the destination ASID is the SOC control por or the OT internal port we are accessing
          // a 32-bit address space. Thus the upper bits of the destination address must be zero
          if ((dst_asid inside {SocControlAddr, OtInternalAddr}) &&
              (|reg2hw.dst_addr_hi.q)) begin
            next_error[DmaDstAddrErr] = 1'b1;
          end

          if (!control_q.range_valid) begin
            next_error[DmaRangeValidErr] = 1'b1;
          end

          // If one or more errors occurred, transition to the error state.
          if (|next_error) begin
            ctrl_state_d = DmaError;
          end else begin
            // Start the inline hashing if we are in the very first transfer. This is indicated
            // when transfer_byte_q is still 0
            if (transfer_byte_q == '0) begin
              if (use_inline_hashing) begin
                sha2_hash_start = 1'b1;
              end
            end
            ctrl_state_d = DmaSendRead;
          end
        end

        DmaSendRead,
        DmaWaitReadResponse: begin
          if (read_rsp_valid) begin
            if (read_rsp_error) begin
              next_error[DmaBusErr] = 1'b1;
              ctrl_state_d          = DmaError;
            end else begin
              capture_return_data = 1'b1;
              // We received data, feed it into the SHA2 engine
              if (use_inline_hashing) begin
                sha2_valid      = 1'b1;
                sha2_consumed_d = sha2_ready;
              end
              ctrl_state_d = DmaSendWrite;
            end
          end else if (read_gnt) begin
            // Only Request handled
            ctrl_state_d = DmaWaitReadResponse;
          end
        end

        DmaSendWrite,
        DmaWaitWriteResponse: begin
          // If using inline hashing and data is not yet consumed, apply it
          if (use_inline_hashing && !sha2_consumed_q) begin
            sha2_valid = 1'b1;
            sha2_consumed_d = sha2_ready;
          end

          if (write_rsp_valid) begin
            if (write_rsp_error) begin
              next_error[DmaBusErr] = 1'b1;
              ctrl_state_d          = DmaError;
            end else begin
              // Advance by the number of bytes just transferred
              transfer_byte_d       = transfer_byte_q + TRANSFER_BYTES_WIDTH'(transfer_width_q);
              chunk_byte_d          = chunk_byte_q + TRANSFER_BYTES_WIDTH'(transfer_width_q);
              capture_transfer_byte = 1'b1;
              capture_chunk_byte    = 1'b1;

              // If we are doing inline hashing and the data was not consumed yet, wait until it is
              // consumed by the SHA engine and then continue.
              if (use_inline_hashing && !(sha2_ready || sha2_consumed_q)) begin
                ctrl_state_d = DmaShaWait;
              end else begin
                // Will there still be more to do _after_ this advance?
                if (transfer_byte_d >= reg2hw.total_data_size.q) begin
                  if (use_inline_hashing) begin
                    ctrl_state_d = DmaShaFinalize;
                  end else begin
                    clear_go     = 1'b1;
                    ctrl_state_d = DmaIdle;
                  end
                end else if (chunk_byte_d >= reg2hw.chunk_data_size.q) begin
                  // Conditionally clear the `go` bit when not being used in hardware handshake
                  // mode.
                  // In non-hardware handshake mode, finishing one chunk should raise the
                  // `chunk_done` IRQ and status bit, reset the `go` bit and await the next
                  // FW-controlled chunk.
                  clear_go     = !control_q.cfg_handshake_en;
                  chunk_done   = !control_q.cfg_handshake_en;
                  ctrl_state_d = DmaIdle;
                end else begin
                  ctrl_state_d = DmaAddrSetup;
                end
              end
            end
          end else if (write_gnt) begin
            // Only Request handled
            ctrl_state_d = DmaWaitWriteResponse;
          end
        end

        DmaShaWait: begin
          // Still waiting for the SHA engine to consume the data
          sha2_valid = 1'b1;

          if (sha2_ready) begin
            // Byte count has already been updated for this transfer
            if (transfer_byte_q >= reg2hw.total_data_size.q) begin
              ctrl_state_d = DmaShaFinalize;
            end else if (chunk_byte_q >= reg2hw.chunk_data_size.q) begin
              // Conditionally clear the `go` bit when not being in hardware handshake mode.
              // In non-hardware handshake mode, finishing one chunk should raise the done IRQ
              // and done bit, and release the `go` bit for the next FW-controlled chunk.
              clear_go     = !control_q.cfg_handshake_en;
              chunk_done   = !control_q.cfg_handshake_en;
              ctrl_state_d = DmaIdle;
            end else begin
              ctrl_state_d = DmaAddrSetup;
            end
          end
        end

        DmaShaFinalize: begin
          if (sha2_hash_done_q) begin
            // Digest is ready, capture it to the CSRs
            sha2_digest_set = 1'b1;
            ctrl_state_d   = DmaIdle;
            clear_go       = 1'b1;
          end
        end

        // Wait here until the error is cleared
        DmaError: begin
          if (!reg2hw.status.error.q) begin
            ctrl_state_d = DmaIdle;
            clear_go     = 1'b1;
          end
        end

        default: begin
          // Should not be reachable
          dma_state_error = 1'b1;
        end
      endcase
    end
  end

  // Collect read data from the appropriate port.
  always_comb begin
    unique case (src_asid)
      OtInternalAddr: dma_rsp_data = dma_host_tlul_rsp_data;
      SocControlAddr: dma_rsp_data = dma_ctn_tlul_rsp_data;
      default:        dma_rsp_data = sys_resp_q.read_data;
    endcase
  end

  // Sub-word selection and replication across the bus width, such that it is available to the
  // destination for any address alignment.
  always_comb begin
    unique case (transfer_width_q)
      // 1B/txn - steer the selected byte to all byte lanes
      3'b001:
        unique casez (req_src_be_q)
          4'b1???: read_return_data_d = {4{dma_rsp_data[31:24]}};
          4'b01??: read_return_data_d = {4{dma_rsp_data[23:16]}};
          4'b001?: read_return_data_d = {4{dma_rsp_data[15:8]}};
          default: read_return_data_d = {4{dma_rsp_data[7:0]}};
        endcase
      // 2B/txn - select and duplicate the appropriate half-word
      // Note that for the final transaction of a transfer, there may be only a single strobe set.
      3'b010:  read_return_data_d = {2{|req_src_be_q[1:0] ? dma_rsp_data[15:0]
                                                          : dma_rsp_data[31:16]}};
      default: read_return_data_d = dma_rsp_data;
    endcase
  end


  prim_flop_en #(
    .Width(top_pkg::TL_DW)
  ) aff_read_return_data (
    .clk_i ( gated_clk             ),
    .rst_ni( rst_ni                ),
    .en_i  ( capture_return_data   ),
    .d_i   ( read_return_data_d    ),
    .q_o   ( read_return_data_q    )
  );

  // Mux the data for the SHA2 engine. When capturing the data we
  // can use the data from the bus, otherwise the captured data from the flop
  //
  // Note: the SHA2 logic expects the `data` and `mask` fields to be populated from the MSBs down.
  assign sha2_data.data = {<<8{capture_return_data ? read_return_data_d :
                                                     read_return_data_q}};
  assign sha2_data.mask = {<<1{req_dst_be_q}};

  // Interrupt logic
  prim_intr_hw #(
    .IntrT ( "Status" )
  ) u_intr_dma_done (
    .clk_i                  ( clk_i                         ),
    .rst_ni                 ( rst_ni                        ),
    .event_intr_i           ( reg2hw.status.done.q          ),
    .reg2hw_intr_enable_q_i ( reg2hw.intr_enable.dma_done.q ),
    .reg2hw_intr_test_q_i   ( reg2hw.intr_test.dma_done.q   ),
    .reg2hw_intr_test_qe_i  ( reg2hw.intr_test.dma_done.qe  ),
    .reg2hw_intr_state_q_i  ( reg2hw.intr_state.dma_done.q  ),
    .hw2reg_intr_state_de_o ( hw2reg.intr_state.dma_done.de ),
    .hw2reg_intr_state_d_o  ( hw2reg.intr_state.dma_done.d  ),
    .intr_o                 ( intr_dma_done_o               )
  );

  prim_intr_hw #(
    .IntrT ( "Status" )
  ) u_intr_chunk_dma_done (
    .clk_i                  ( clk_i                               ),
    .rst_ni                 ( rst_ni                              ),
    .event_intr_i           ( reg2hw.status.chunk_done.q          ),
    .reg2hw_intr_enable_q_i ( reg2hw.intr_enable.dma_chunk_done.q ),
    .reg2hw_intr_test_q_i   ( reg2hw.intr_test.dma_chunk_done.q   ),
    .reg2hw_intr_test_qe_i  ( reg2hw.intr_test.dma_chunk_done.qe  ),
    .reg2hw_intr_state_q_i  ( reg2hw.intr_state.dma_chunk_done.q  ),
    .hw2reg_intr_state_de_o ( hw2reg.intr_state.dma_chunk_done.de ),
    .hw2reg_intr_state_d_o  ( hw2reg.intr_state.dma_chunk_done.d  ),
    .intr_o                 ( intr_dma_chunk_done_o               )
  );

  prim_intr_hw #(
    .IntrT ( "Status" )
  ) u_intr_error (
    .clk_i                  ( clk_i                          ),
    .rst_ni                 ( rst_ni                         ),
    .event_intr_i           ( reg2hw.status.error.q          ),
    .reg2hw_intr_enable_q_i ( reg2hw.intr_enable.dma_error.q ),
    .reg2hw_intr_test_q_i   ( reg2hw.intr_test.dma_error.q   ),
    .reg2hw_intr_test_qe_i  ( reg2hw.intr_test.dma_error.qe  ),
    .reg2hw_intr_state_q_i  ( reg2hw.intr_state.dma_error.q  ),
    .hw2reg_intr_state_de_o ( hw2reg.intr_state.dma_error.de ),
    .hw2reg_intr_state_d_o  ( hw2reg.intr_state.dma_error.d  ),
    .intr_o                 ( intr_dma_error_o               )
  );

  logic data_move_state;
  logic update_dst_addr_reg, update_src_addr_reg;

  assign data_move_state = (ctrl_state_q == DmaSendWrite)         ||
                           (ctrl_state_q == DmaWaitWriteResponse) ||
                           (ctrl_state_q == DmaShaWait)           ||
                           (ctrl_state_q == DmaShaFinalize);



  // Calculate the number of bytes remaining until the end of the current chunk.
  // Note that the total transfer size may be a non-integral multiple of the programmed chunk size,
  // so we must consider the `total_data_size` here too; this is important in determining the
  // correct write strobes for the final word of the transfer.
  assign transfer_remaining_bytes = reg2hw.total_data_size.q - transfer_byte_q;
  assign chunk_remaining_bytes = reg2hw.chunk_data_size.q - chunk_byte_q;
  assign remaining_bytes = (transfer_remaining_bytes < chunk_remaining_bytes) ?
                            transfer_remaining_bytes : chunk_remaining_bytes;

  always_comb begin
    // Because of using the primitives for interrupt handling, the hw2reg registers cannot be
    // collectively assigned a default value since that would create a second driver to the
    // interrupt registers.
    // Thus we must ensure that all registers are initialized manually to avoid creating latches.

    // Clear the `go` bit if we are in a single transfer and finished the DMA operation,
    // hardware handshake mode when we finished all transfers, or when aborting the transfer.
    hw2reg.control.go.de = clear_go || cfg_abort_en;
    hw2reg.control.go.d  = 1'b0;

    // Unlock the register set when not busy. IDLE is not the right indicator,
    // since multi-chunked transfers roundtrip via IDLE.
    hw2reg.cfg_regwen.d = prim_mubi_pkg::mubi4_bool_to_mubi(~reg2hw.status.busy.q);

    // When we would update the register, we would update it with the current transferred number of
    // bytes of the current chunk
    new_dst_addr = {reg2hw.dst_addr_hi.q, reg2hw.dst_addr_lo.q} +
                    SYS_ADDR_WIDTH'(reg2hw.chunk_data_size.q);
    new_src_addr = {reg2hw.src_addr_hi.q, reg2hw.src_addr_lo.q} +
                    SYS_ADDR_WIDTH'(reg2hw.chunk_data_size.q);

    // If we are in multi-chunk mode, we need to update the register addresses since they are needed
    // for the next chunk. Do this only when going back to Idle and when we are incrementing the
    // address but not doing wrap-around.
    update_dst_addr_reg = 1'b0;
    update_src_addr_reg = 1'b0;
    if (data_move_state && (ctrl_state_d == DmaIdle)) begin
      if (reg2hw.src_config.increment.q == AddrNoIncrement &&
          reg2hw.src_config.wrap.q == AddrNoWrapChunk) begin
        update_src_addr_reg = 1'b1;
      end
      if (reg2hw.dst_config.increment.q == AddrNoIncrement &&
          reg2hw.dst_config.wrap.q == AddrNoWrapChunk) begin
        update_dst_addr_reg = 1'b1;
      end
    end

    hw2reg.dst_addr_hi.de = update_dst_addr_reg;
    hw2reg.dst_addr_hi.d  = new_dst_addr[63:32];

    hw2reg.dst_addr_lo.de = update_dst_addr_reg;
    hw2reg.dst_addr_lo.d  = new_dst_addr[31:0];

    hw2reg.src_addr_hi.de = update_src_addr_reg;
    hw2reg.src_addr_hi.d  = new_src_addr[63:32];

    hw2reg.src_addr_lo.de = update_src_addr_reg;
    hw2reg.src_addr_lo.d  = new_src_addr[31:0];

    hw2reg.control.initial_transfer.de = 1'b0;
    hw2reg.control.initial_transfer.d  = 1'b0;
    // Clear the `initial transfer` flag when leaving the DmaIdle state the first time.
    if ((ctrl_state_q == DmaIdle) && (ctrl_state_d != DmaIdle) &&
        reg2hw.control.initial_transfer.q) begin
      hw2reg.control.initial_transfer.de = 1'b1;
    end

    // Assert busy write enable on
    // - transitions from IDLE out
    // - clearing the `go` bit (going back to idle)
    // - abort                 (going back to idle)
    hw2reg.status.busy.de = ((ctrl_state_q == DmaIdle) && (ctrl_state_d != DmaIdle)) ||
                            clear_go                                                 ||
                            cfg_abort_en;
    // If transitioning from IDLE, set busy, otherwise clear it
    hw2reg.status.busy.d  = ((ctrl_state_q == DmaIdle) && (ctrl_state_d != DmaIdle)) ? 1'b1 : 1'b0;

    // Status is cleared when leaving the IDLE state the first time, i.e., when busy is not yet set
    clear_status = (ctrl_state_q == DmaIdle) && (ctrl_state_d != DmaIdle) && !reg2hw.status.busy.q;
    // The SHA digest valid and the digest itself needs to incorporate the initial transfer flag as
    // busy is deasserted for every chunk in the middle of a multi-chunk memory-to-memory transfer
    clear_sha_status = (ctrl_state_q == DmaIdle) && (ctrl_state_d != DmaIdle) &&
                       reg2hw.control.initial_transfer.q;

    // Set the done bit only when finishing all chunks. Automatically clear the done bit when
    // starting a new transfer
    hw2reg.status.done.de = ((!cfg_abort_en) && data_move_state && clear_go && ~chunk_done) |
                            clear_status;
    hw2reg.status.done.d  = clear_status? 1'b0 : 1'b1;

    hw2reg.status.error.de = (ctrl_state_d == DmaError) | clear_status;
    hw2reg.status.error.d  = clear_status? 1'b0 : 1'b1;

    hw2reg.status.aborted.de = cfg_abort_en | clear_status;
    hw2reg.status.aborted.d  = clear_status? 1'b0 : 1'b1;

    hw2reg.status.sha2_digest_valid.de = sha2_digest_set | clear_sha_status;
    hw2reg.status.sha2_digest_valid.d  = sha2_digest_set;

    hw2reg.status.chunk_done.de = ((!cfg_abort_en) && chunk_done) | clear_status;
    hw2reg.status.chunk_done.d  = clear_status? 1'b0 : 1'b1;

    // Write digest to CSRs when needed. The digest is an 8-element 64-bit datatype. Depending on
    // the selected hashing algorithm, the digest is stored differently in the digest datatype:
    // SHA2-256: digest[0-7][31:0] store the 256-bit digest. The upper 32-bits of all digest
    //           elements are zero
    // SHA2-384: digest[0-5][63:0] store the 384-bit digest.
    // SHA2-512: digest[0-7][63:0] store the 512-bit digest.
    for (int i = 0; i < NR_SHA_DIGEST_ELEMENTS; i++) begin
      hw2reg.sha2_digest[i].de = sha2_digest_set | clear_sha_status;
      hw2reg.sha2_digest[i].d  = '0;
    end

    // Only mux the digest data when sha2_digest_set is set. Setting the digest happens during the
    // DmaFinalze state, where we need to use the stored and locked `control_q.opcode` value.
    // In case of clear_sha_status being asserted, the default value from hw2reg = '0; clears
    // the digest
    if (sha2_digest_set) begin
      for (int unsigned i = 0; i < NR_SHA_DIGEST_ELEMENTS / 2; i++) begin
        unique case (control_q.opcode)
          OpcSha256: begin
            hw2reg.sha2_digest[i].d = conv_endian32(sha2_digest[i][0 +: 32],
                                                    control_q.cfg_digest_swap);
          end
          OpcSha384: begin
            if (i < 6) begin
              hw2reg.sha2_digest[i*2].d     = conv_endian32(sha2_digest[i][32 +: 32],
                                                            control_q.cfg_digest_swap);
              hw2reg.sha2_digest[(i*2)+1].d = conv_endian32(sha2_digest[i][0  +: 32],
                                                            control_q.cfg_digest_swap);
            end
          end
          default: begin // SHA2-512
            hw2reg.sha2_digest[i*2].d     = conv_endian32(sha2_digest[i][32 +: 32],
                                                          control_q.cfg_digest_swap);
            hw2reg.sha2_digest[(i*2)+1].d = conv_endian32(sha2_digest[i][0  +: 32],
                                                          control_q.cfg_digest_swap);
          end
        endcase
      end
    end

    // Set the error code only when entering the error state
    set_error_code = (ctrl_state_q != DmaError) && (ctrl_state_d == DmaError);

    // Fiddle out error signals
    hw2reg.error_code.src_addr_error.de    = set_error_code | clear_status;
    hw2reg.error_code.dst_addr_error.de    = set_error_code | clear_status;
    hw2reg.error_code.opcode_error.de      = set_error_code | clear_status;
    hw2reg.error_code.size_error.de        = set_error_code | clear_status;
    hw2reg.error_code.bus_error.de         = set_error_code | clear_status;
    hw2reg.error_code.base_limit_error.de  = set_error_code | clear_status;
    hw2reg.error_code.range_valid_error.de = set_error_code | clear_status;
    hw2reg.error_code.asid_error.de        = set_error_code | clear_status;

    hw2reg.error_code.src_addr_error.d     = clear_status? '0 : next_error[DmaSrcAddrErr];
    hw2reg.error_code.dst_addr_error.d     = clear_status? '0 : next_error[DmaDstAddrErr];
    hw2reg.error_code.opcode_error.d       = clear_status? '0 : next_error[DmaOpcodeErr];
    hw2reg.error_code.size_error.d         = clear_status? '0 : next_error[DmaSizeErr];
    hw2reg.error_code.bus_error.d          = clear_status? '0 : next_error[DmaBusErr];
    hw2reg.error_code.base_limit_error.d   = clear_status? '0 : next_error[DmaBaseLimitErr];
    hw2reg.error_code.range_valid_error.d  = clear_status? '0 : next_error[DmaRangeValidErr];
    hw2reg.error_code.asid_error.d         = clear_status? '0 : next_error[DmaAsidErr];

    // Clear the `control.abort` bit once we have handled the abort request
    hw2reg.control.abort.de = hw2reg.status.aborted.de;
    hw2reg.control.abort.d  = 1'b0;

    // Clear the SHA2 digests if the SHA2 valid flag is cleared (RW1C)
    if (reg2hw.status.sha2_digest_valid.qe & reg2hw.status.sha2_digest_valid.q) begin
      for (int i = 0; i < NR_SHA_DIGEST_ELEMENTS; i++) begin
        hw2reg.sha2_digest[i].de = 1'b0;
        hw2reg.sha2_digest[i].d  = '0;
      end
    end

    // Clear the error code if the error flag is cleared (RW1C)
    if (reg2hw.status.error.qe & reg2hw.status.error.q) begin
      // Clear all errors
      hw2reg.error_code.src_addr_error.de = 1'b1;
      hw2reg.error_code.dst_addr_error.de = 1'b1;
      hw2reg.error_code.opcode_error.de      = 1'b1;
      hw2reg.error_code.size_error.de        = 1'b1;
      hw2reg.error_code.bus_error.de         = 1'b1;
      hw2reg.error_code.base_limit_error.de  = 1'b1;
      hw2reg.error_code.range_valid_error.de = 1'b1;
      hw2reg.error_code.asid_error.de        = 1'b1;

      hw2reg.error_code.src_addr_error.d  = 1'b0;
      hw2reg.error_code.dst_addr_error.d  = 1'b0;
      hw2reg.error_code.opcode_error.d       = 1'b0;
      hw2reg.error_code.size_error.d         = 1'b0;
      hw2reg.error_code.bus_error.d          = 1'b0;
      hw2reg.error_code.base_limit_error.d   = 1'b0;
      hw2reg.error_code.range_valid_error.d  = 1'b0;
      hw2reg.error_code.asid_error.d         = 1'b0;
    end
  end

  //////////////////////////////////////////////////////////////////////////////
  // Interface signal flopping
  //////////////////////////////////////////////////////////////////////////////

  prim_flop #(
    .Width(SYS_NUM_REQ_CH)
  ) u_sys_vld_vec (
    .clk_i ( gated_clk         ),
    .rst_ni( rst_ni            ),
    .d_i   ( sys_req_d.vld_vec ),
    .q_o   ( sys_o.vld_vec     )
  );

  prim_flop_en #(
    .Width(SYS_METADATA_WIDTH)
  ) u_sys_metadata_write_vec (
    .clk_i ( gated_clk                           ),
    .rst_ni( rst_ni                              ),
    .en_i  ( sys_req_d.vld_vec[SysCmdWrite]      ),
    .d_i   ( sys_req_d.metadata_vec[SysCmdWrite] ),
    .q_o   ( sys_o.metadata_vec[SysCmdWrite]     )
  );

  logic [$bits(sys_opc_e)-1:0] sys_req_opcode_write_vec_q;
  prim_flop_en #(
    .Width($bits(sys_opc_e))
  ) u_sys_opcode_write_vec (
    .clk_i ( gated_clk                         ),
    .rst_ni( rst_ni                            ),
    .en_i  ( sys_req_d.vld_vec[SysCmdWrite]    ),
    .d_i   ( sys_req_d.opcode_vec[SysCmdWrite] ),
    .q_o   ( sys_req_opcode_write_vec_q        )
  );
  assign sys_o.opcode_vec[SysCmdWrite] = sys_opc_e'(sys_req_opcode_write_vec_q);

  prim_flop_en #(
    .Width(SYS_ADDR_WIDTH)
  ) u_sys_iova_write_vec (
    .clk_i ( gated_clk                       ),
    .rst_ni( rst_ni                          ),
    .en_i  ( sys_req_d.vld_vec[SysCmdWrite]  ),
    .d_i   ( sys_req_d.iova_vec[SysCmdWrite] ),
    .q_o   ( sys_o.iova_vec[SysCmdWrite]     )
  );

  prim_flop_en #(
    .Width(SYS_RACL_WIDTH)
  ) u_sys_racl_write_vec (
    .clk_i ( gated_clk                       ),
    .rst_ni( rst_ni                          ),
    .en_i  ( sys_req_d.vld_vec[SysCmdWrite]  ),
    .d_i   ( sys_req_d.racl_vec[SysCmdWrite] ),
    .q_o   ( sys_o.racl_vec[SysCmdWrite]     )
  );

  prim_flop_en #(
    .Width(SYS_METADATA_WIDTH)
  ) u_sys_metadata_read_vec (
    .clk_i ( gated_clk                          ),
    .rst_ni( rst_ni                             ),
    .en_i  ( sys_req_d.vld_vec[SysCmdRead]      ),
    .d_i   ( sys_req_d.metadata_vec[SysCmdRead] ),
    .q_o   ( sys_o.metadata_vec[SysCmdRead]     )
  );

  logic [$bits(sys_opc_e)-1:0] sys_req_opcode_read_vec_q;
  prim_flop_en #(
    .Width($bits(sys_opc_e))
  ) u_sys_opcode_read_vec (
    .clk_i ( gated_clk                        ),
    .rst_ni( rst_ni                           ),
    .en_i  ( sys_req_d.vld_vec[SysCmdRead]    ),
    .d_i   ( sys_req_d.opcode_vec[SysCmdRead] ),
    .q_o   ( sys_req_opcode_read_vec_q        )
  );
  assign sys_o.opcode_vec[SysCmdRead] = sys_opc_e'(sys_req_opcode_read_vec_q);

  prim_flop_en #(
    .Width(SYS_ADDR_WIDTH)
  ) u_sys_iova_read_vec (
    .clk_i ( gated_clk                      ),
    .rst_ni( rst_ni                         ),
    .en_i  ( sys_req_d.vld_vec[SysCmdRead]  ),
    .d_i   ( sys_req_d.iova_vec[SysCmdRead] ),
    .q_o   ( sys_o.iova_vec[SysCmdRead]     )
  );

  prim_flop_en #(
    .Width(SYS_RACL_WIDTH)
  ) u_sys_racl_read_vec (
    .clk_i ( gated_clk                      ),
    .rst_ni( rst_ni                         ),
    .en_i  ( sys_req_d.vld_vec[SysCmdRead]  ),
    .d_i   ( sys_req_d.racl_vec[SysCmdRead] ),
    .q_o   ( sys_o.racl_vec[SysCmdRead]     )
  );

  prim_flop_en #(
    .Width(SYS_DATA_WIDTH)
  ) u_sys_write_data (
    .clk_i ( gated_clk                      ),
    .rst_ni( rst_ni                         ),
    .en_i  ( sys_req_d.vld_vec[SysCmdWrite] ),
    .d_i   ( sys_req_d.write_data           ),
    .q_o   ( sys_o.write_data               )
  );

  prim_flop_en #(
    .Width(SYS_DATA_BYTEWIDTH)
  ) u_sys_write_be (
    .clk_i ( gated_clk                      ),
    .rst_ni( rst_ni                         ),
    .en_i  ( sys_req_d.vld_vec[SysCmdWrite] ),
    .d_i   ( sys_req_d.write_be             ),
    .q_o   ( sys_o.write_be                 )
  );

  prim_flop_en #(
    .Width(SYS_DATA_BYTEWIDTH)
  ) u_sys_read_be (
    .clk_i ( gated_clk                      ),
    .rst_ni( rst_ni                         ),
    .en_i  ( sys_req_d.vld_vec[SysCmdRead ] ),
    .d_i   ( sys_req_d.read_be              ),
    .q_o   ( sys_o.read_be                  )
  );

  prim_flop #(
    .Width(SYS_NUM_REQ_CH)
  ) u_sys_gnt_vec (
    .clk_i ( gated_clk            ),
    .rst_ni( rst_ni               ),
    .d_i   ( sys_i.grant_vec      ),
    .q_o   ( sys_resp_q.grant_vec )
  );

  prim_flop #(
    .Width(1)
  ) u_sys_read_data_valid (
    .clk_i ( gated_clk                ),
    .rst_ni( rst_ni                   ),
    .d_i   ( sys_i.read_data_vld      ),
    .q_o   ( sys_resp_q.read_data_vld )
  );

  prim_flop #(
    .Width(SYS_DATA_WIDTH)
  ) u_sys_read_data (
    .clk_i ( gated_clk            ),
    .rst_ni( rst_ni               ),
    .d_i   ( sys_i.read_data      ),
    .q_o   ( sys_resp_q.read_data )
  );

  prim_flop #(
    .Width(SYS_METADATA_WIDTH)
  ) u_sys_read_metadata (
    .clk_i ( gated_clk                ),
    .rst_ni( rst_ni                   ),
    .d_i   ( sys_i.read_metadata      ),
    .q_o   ( sys_resp_q.read_metadata )
  );

  prim_flop #(
    .Width(1)
  ) u_sys_read_error_valid (
    .clk_i ( gated_clk            ),
    .rst_ni( rst_ni               ),
    .d_i   ( sys_i.error_vld      ),
    .q_o   ( sys_resp_q.error_vld )
  );

  prim_flop #(
    .Width(SYS_NUM_ERROR_TYPES)
  ) u_sys_read_error (
    .clk_i ( gated_clk            ),
    .rst_ni( rst_ni               ),
    .d_i   ( sys_i.error_vec      ),
    .q_o   ( sys_resp_q.error_vec )
  );

  //////////////////////////////////////////////////////////////////////////////
  // Unused signals
  //////////////////////////////////////////////////////////////////////////////
  logic unused_signals;
  assign unused_signals = ^{reg2hw.enabled_memory_range_base.qe,
                            reg2hw.enabled_memory_range_limit.qe,
                            reg2hw.range_regwen.q,
                            sys_resp_q.error_vec,
                            sys_resp_q.read_metadata,
                            sys_resp_q.grant_vec[SysCmdRead]};

  //////////////////////////////////////////////////////////////////////////////
  // Assertions
  //////////////////////////////////////////////////////////////////////////////

  // All outputs should be known values after reset
  `ASSERT_KNOWN(AlertsKnown_A, alert_tx_o)
  `ASSERT_KNOWN_IF(RaclErrorOKnown_A, racl_error_o, racl_error_o.valid)
  `ASSERT_KNOWN(IntrDmaDoneKnown_A, intr_dma_done_o)
  `ASSERT_KNOWN(IntrDmaChunkDoneKnown_A, intr_dma_chunk_done_o)
  `ASSERT_KNOWN(IntrDmaErrorKnown_A, intr_dma_error_o)

  `ASSERT_KNOWN(TlDValidKnownO_A, tl_d_o.d_valid)
  `ASSERT_KNOWN(TlAReadyKnownO_A, tl_d_o.a_ready)

  `ASSERT_KNOWN(CtnTlAValidKnownO_A, ctn_tl_h2d_o.a_valid)
  `ASSERT_KNOWN(CtnTlDReadyKnownO_A, ctn_tl_h2d_o.d_ready)
  `ASSERT_KNOWN(HostTlAValidKnownO_A, host_tl_h_o.a_valid)
  `ASSERT_KNOWN(HostTlDReadyKnownO_A, host_tl_h_o.d_ready)

  `ASSERT_KNOWN(SysValidKnownO_A, sys_o.vld_vec)

  // Alert assertions for reg_we onehot check
  `ASSERT_PRIM_REG_WE_ONEHOT_ERROR_TRIGGER_ALERT(RegWeOnehotCheck_A, u_dma_reg, alert_tx_o[0])

  // Handshake interrupt enable register must be expanded if there are more than 32 handshake
  // trigger wires
  `ASSERT_NEVER(LimitHandshakeTriggerWires_A, NumIntClearSources > 32)

  // The RTL code assumes the BE signal is 4-bit wide
  `ASSERT_NEVER(BeLengthMustBe4_A, top_pkg::TL_DBW != 4)

  // The DMA enabled memory should not be changed after lock
  `ASSERT_NEVER(NoDmaEnabledMemoryChangeAfterLock_A,
                prim_mubi_pkg::mubi4_test_false_loose(
                  prim_mubi_pkg::mubi4_t'(reg2hw.range_regwen.q)) &&
                  (reg2hw.enabled_memory_range_base.qe ||
                   reg2hw.enabled_memory_range_limit.qe))

  // Alert assertion for sparse FSM.
  `ASSERT_PRIM_FSM_ERROR_TRIGGER_ALERT(CtrlStateFsmCheck_A, aff_ctrl_state_q, alert_tx_o[0])
endmodule
