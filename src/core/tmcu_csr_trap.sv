`timescale 1ns/1ps
`include "tmcu_defs.svh"

module tmcu_csr_trap #(
  parameter logic [31:0] MTVEC_RESET = 32'h0000_0000,
  parameter bit SHADOW_BANK_ENABLE = 1'b1,
  // Physical width of mcycle / minstret (1..64). CSR *h reads zero when <= 32.
  parameter int unsigned COUNTER_WIDTH = 64
) (
  input  logic        clk_i,
  input  logic        rst_ni,

  input  logic [11:0] csr_check_addr_i,
  output logic        csr_check_valid_o,
  input  logic [11:0] csr_access_addr_i,
  output logic [31:0] csr_access_rdata_o,
  output logic        csr_access_valid_o,
  input  logic        csr_write_i,
  input  logic [11:0] csr_write_addr_i,
  input  logic [31:0] csr_write_data_i,

  input  logic        trap_enter_i,
  input  logic        trap_interrupt_i,
  // cause[31] ignored: interrupt bit comes from trap_interrupt_i
  /* verilator lint_off UNUSEDSIGNAL */
  input  logic [31:0] trap_cause_i,
  /* verilator lint_on  UNUSEDSIGNAL */
  input  logic [31:0] trap_value_i,
  // epc[0] ignored: IALIGN forces mepc[0]=0
  /* verilator lint_off UNUSEDSIGNAL */
  input  logic [31:0] trap_epc_i,
  /* verilator lint_on  UNUSEDSIGNAL */
  input  logic        mret_i,
  input  logic        instruction_retired_i,

  input  logic        irq_software_i,
  input  logic        irq_timer_i,
  input  logic        irq_external_i,

  output logic [31:0] trap_vector_o,
  output logic [31:0] mepc_o,
  output logic        interrupt_request_o,
  output logic [31:0] interrupt_cause_o,
  output logic        shadow_bank_o,

  // Continuous observe ports (student BD waveform / IP debug pins)
  output logic [31:0] dbg_csr_mstatus_o,
  output logic [31:0] dbg_csr_mie_o,
  output logic [31:0] dbg_csr_mtvec_o,
  output logic [31:0] dbg_csr_mscratch_o,
  output logic [31:0] dbg_csr_mepc_o,
  output logic [31:0] dbg_csr_mcause_o,
  output logic [31:0] dbg_csr_mtval_o,
  output logic [31:0] dbg_csr_mip_o,
  output logic [31:0] dbg_csr_mcycle_o,
  output logic [31:0] dbg_csr_mcycleh_o,
  output logic [31:0] dbg_csr_minstret_o,
  output logic [31:0] dbg_csr_minstreth_o
);
  // Clamp to a synthesizable 1..64 range.
  localparam int unsigned CTR_W =
      (COUNTER_WIDTH < 1) ? 1 : ((COUNTER_WIDTH > 64) ? 64 : COUNTER_WIDTH);
  localparam int unsigned CTR_PAD = 64 - CTR_W;

  logic [31:0] mstatus_q;
  logic [31:0] mie_q;
  logic [31:0] mtvec_q;
  logic [31:0] mscratch_q;
  logic [31:0] mepc_q;
  logic [31:0] mcause_q;
  logic [31:0] mtval_q;
  logic [31:0] mip_software_q;
  logic [CTR_W-1:0] mcycle_q;
  logic [CTR_W-1:0] minstret_q;
  logic [63:0] mcycle_ext;
  logic [63:0] minstret_ext;
  logic [63:0] mcycle_wr_lo;
  logic [63:0] mcycle_wr_hi;
  logic [63:0] minstret_wr_lo;
  logic [63:0] minstret_wr_hi;
  logic [31:0] mip_value;
  logic        irq_ext_pend;
  logic        irq_sw_pend;
  logic        irq_tm_pend;

  // Zero-width pad (CTR_W==64) is illegal in some SV frontends — branch it.
  if (CTR_PAD == 0) begin : g_ctr_full
    assign mcycle_ext   = mcycle_q;
    assign minstret_ext = minstret_q;
  end else begin : g_ctr_pad
    assign mcycle_ext   = {{CTR_PAD{1'b0}}, mcycle_q};
    assign minstret_ext = {{CTR_PAD{1'b0}}, minstret_q};
  end
  // Avoid concat-then-select (YoWASP/Yosys SV frontend limitation).
  assign mcycle_wr_lo   = {mcycle_ext[63:32], csr_write_data_i};
  assign mcycle_wr_hi   = {csr_write_data_i, mcycle_ext[31:0]};
  assign minstret_wr_lo = {minstret_ext[63:32], csr_write_data_i};
  assign minstret_wr_hi = {csr_write_data_i, minstret_ext[31:0]};

  function automatic logic csr_address_valid(input logic [11:0] address);
    begin
      unique case (address)
        `TMCU_CSR_MSTATUS,
        `TMCU_CSR_MIE,
        `TMCU_CSR_MTVEC,
        `TMCU_CSR_MSCRATCH,
        `TMCU_CSR_MEPC,
        `TMCU_CSR_MCAUSE,
        `TMCU_CSR_MTVAL,
        `TMCU_CSR_MIP,
        `TMCU_CSR_MCYCLE,
        `TMCU_CSR_MCYCLEH,
        `TMCU_CSR_MINSTRET,
        `TMCU_CSR_MINSTRETH: csr_address_valid = 1'b1;
        default:             csr_address_valid = 1'b0;
      endcase
    end
  endfunction

  assign csr_check_valid_o  = csr_address_valid(csr_check_addr_i);
  assign csr_access_valid_o = csr_address_valid(csr_access_addr_i);

  always_comb begin
    mip_value = mip_software_q;
    mip_value[3]  = mip_software_q[3]  | irq_software_i;
    mip_value[7]  = mip_software_q[7]  | irq_timer_i;
    mip_value[11] = mip_software_q[11] | irq_external_i;

    csr_access_rdata_o = 32'b0;
    unique case (csr_access_addr_i)
      `TMCU_CSR_MSTATUS:   csr_access_rdata_o = mstatus_q;
      `TMCU_CSR_MIE:       csr_access_rdata_o = mie_q;
      `TMCU_CSR_MTVEC:     csr_access_rdata_o = mtvec_q;
      `TMCU_CSR_MSCRATCH:  csr_access_rdata_o = mscratch_q;
      `TMCU_CSR_MEPC:      csr_access_rdata_o = mepc_q;
      `TMCU_CSR_MCAUSE:    csr_access_rdata_o = mcause_q;
      `TMCU_CSR_MTVAL:     csr_access_rdata_o = mtval_q;
      `TMCU_CSR_MIP:       csr_access_rdata_o = mip_value;
      `TMCU_CSR_MCYCLE:    csr_access_rdata_o = mcycle_ext[31:0];
      `TMCU_CSR_MCYCLEH:   csr_access_rdata_o = mcycle_ext[63:32];
      `TMCU_CSR_MINSTRET:  csr_access_rdata_o = minstret_ext[31:0];
      `TMCU_CSR_MINSTRETH: csr_access_rdata_o = minstret_ext[63:32];
      default:             csr_access_rdata_o = 32'b0;
    endcase
  end

  assign irq_ext_pend = mie_q[11] & mip_value[11];
  assign irq_sw_pend  = mie_q[3]  & mip_value[3];
  assign irq_tm_pend  = mie_q[7]  & mip_value[7];
  assign interrupt_request_o = mstatus_q[3] &&
    (irq_ext_pend || irq_sw_pend || irq_tm_pend);

  always_comb begin
    if (irq_ext_pend) begin
      interrupt_cause_o = `TMCU_INTERRUPT_EXTERNAL;
    end else if (irq_sw_pend) begin
      interrupt_cause_o = `TMCU_INTERRUPT_SOFTWARE;
    end else begin
      interrupt_cause_o = `TMCU_INTERRUPT_TIMER;
    end
  end

  assign trap_vector_o = {mtvec_q[31:2], 2'b00};
  assign mepc_o        = mepc_q;

  assign dbg_csr_mstatus_o   = mstatus_q;
  assign dbg_csr_mie_o       = mie_q;
  assign dbg_csr_mtvec_o     = mtvec_q;
  assign dbg_csr_mscratch_o  = mscratch_q;
  assign dbg_csr_mepc_o      = mepc_q;
  assign dbg_csr_mcause_o    = mcause_q;
  assign dbg_csr_mtval_o     = mtval_q;
  assign dbg_csr_mip_o       = mip_value;
  assign dbg_csr_mcycle_o    = mcycle_ext[31:0];
  assign dbg_csr_mcycleh_o   = mcycle_ext[63:32];
  assign dbg_csr_minstret_o  = minstret_ext[31:0];
  assign dbg_csr_minstreth_o = minstret_ext[63:32];

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      mstatus_q      <= 32'h0000_1800;
      mie_q          <= 32'b0;
      mtvec_q        <= {MTVEC_RESET[31:2], 2'b00};
      mscratch_q     <= 32'b0;
      mepc_q         <= 32'b0;
      mcause_q       <= 32'b0;
      mtval_q        <= 32'b0;
      mip_software_q <= 32'b0;
      shadow_bank_o  <= 1'b0;
    end else begin
      if (csr_write_i) begin
        unique case (csr_write_addr_i)
          `TMCU_CSR_MSTATUS: begin
            mstatus_q[3]     <= csr_write_data_i[3];
            mstatus_q[7]     <= csr_write_data_i[7];
            mstatus_q[12:11] <= 2'b11;
          end
          `TMCU_CSR_MIE: begin
            mie_q       <= 32'b0;
            mie_q[3]    <= csr_write_data_i[3];
            mie_q[7]    <= csr_write_data_i[7];
            mie_q[11]   <= csr_write_data_i[11];
          end
          `TMCU_CSR_MTVEC:    mtvec_q    <= {csr_write_data_i[31:2], 2'b00};
          `TMCU_CSR_MSCRATCH: mscratch_q <= csr_write_data_i;
          `TMCU_CSR_MEPC:     mepc_q     <= {csr_write_data_i[31:1], 1'b0};
          `TMCU_CSR_MCAUSE:   mcause_q   <= csr_write_data_i;
          `TMCU_CSR_MTVAL:    mtval_q    <= csr_write_data_i;
          `TMCU_CSR_MIP: begin
            mip_software_q       <= 32'b0;
            mip_software_q[3]    <= csr_write_data_i[3];
            mip_software_q[7]    <= csr_write_data_i[7];
            mip_software_q[11]   <= csr_write_data_i[11];
          end
          default: begin end
        endcase
      end

      if (mret_i) begin
        mstatus_q[3]     <= mstatus_q[7];
        mstatus_q[7]     <= 1'b1;
        mstatus_q[12:11] <= 2'b11;
        shadow_bank_o    <= 1'b0;
      end

      if (trap_enter_i) begin
        // IALIGN=16 (C): mepc[0] WARL 0, mepc[1] must be writable.
        mepc_q            <= {trap_epc_i[31:1], 1'b0};
        mcause_q          <= trap_interrupt_i
          ? {1'b1, trap_cause_i[30:0]}
          : {1'b0, trap_cause_i[30:0]};
        mtval_q           <= trap_value_i;
        mstatus_q[7]      <= mstatus_q[3];
        mstatus_q[3]      <= 1'b0;
        mstatus_q[12:11]  <= 2'b11;
        shadow_bank_o     <= SHADOW_BANK_ENABLE;
      end
    end
  end

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      mcycle_q <= '0;
    end else if (csr_write_i && (csr_write_addr_i == `TMCU_CSR_MCYCLE)) begin
      mcycle_q <= mcycle_wr_lo[CTR_W-1:0];
    end else if (csr_write_i && (csr_write_addr_i == `TMCU_CSR_MCYCLEH)) begin
      mcycle_q <= mcycle_wr_hi[CTR_W-1:0];
    end else begin
      mcycle_q <= mcycle_q + {{(CTR_W-1){1'b0}}, 1'b1};
    end
  end

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      minstret_q <= '0;
    end else if (csr_write_i && (csr_write_addr_i == `TMCU_CSR_MINSTRET)) begin
      minstret_q <= minstret_wr_lo[CTR_W-1:0];
    end else if (csr_write_i && (csr_write_addr_i == `TMCU_CSR_MINSTRETH)) begin
      minstret_q <= minstret_wr_hi[CTR_W-1:0];
    end else if (instruction_retired_i) begin
      minstret_q <= minstret_q + {{(CTR_W-1){1'b0}}, 1'b1};
    end
  end
endmodule
