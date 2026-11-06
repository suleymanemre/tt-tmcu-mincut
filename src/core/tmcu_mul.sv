`timescale 1ns/1ps
// Multiplier unit for RV32M (33x33 signed multiplier).
// Parametric:
//   SINGLE_CYCLE = 0 : 1-cycle pipelined (EX/MEM timing cut, infers DSP output register, high fMAX).
//   SINGLE_CYCLE = 1 : Single-cycle combinational (max IPC, for <= 50 MHz).
`include "tmcu_defs.svh"

module tmcu_mul #(
  parameter bit SINGLE_CYCLE = 1'b0
) (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        start_i,
  input  logic        flush_i,
  input  logic        result_ack_i,
  input  logic [4:0]  operation_i,
  input  logic [31:0] operand_a_i,
  input  logic [31:0] operand_b_i,
  output logic        busy_o,
  output logic        done_o,
  output logic [31:0] result_o
);
  logic signed [32:0] a_ext;
  logic signed [32:0] b_ext;
  /* verilator lint_off UNUSEDSIGNAL */
  logic signed [65:0] product_comb;
  /* verilator lint_on  UNUSEDSIGNAL */

  function automatic logic is_high_mul(input logic [4:0] op);
    return (op == `TMCU_ALU_MULH) ||
           (op == `TMCU_ALU_MULHSU) ||
           (op == `TMCU_ALU_MULHU);
  endfunction

  always_comb begin
    unique case (operation_i)
      `TMCU_ALU_MUL,
      `TMCU_ALU_MULH: begin
        a_ext = {operand_a_i[31], operand_a_i};
        b_ext = {operand_b_i[31], operand_b_i};
      end
      `TMCU_ALU_MULHSU: begin
        a_ext = {operand_a_i[31], operand_a_i};
        b_ext = {1'b0, operand_b_i};
      end
      default: begin // MULHU
        a_ext = {1'b0, operand_a_i};
        b_ext = {1'b0, operand_b_i};
      end
    endcase

    product_comb = a_ext * b_ext;
  end

  if (SINGLE_CYCLE) begin : g_single_cycle
    /* verilator lint_off UNUSEDSIGNAL */
    logic _unused;
    assign _unused = &{1'b0, clk_i, rst_ni, start_i, flush_i, result_ack_i, 1'b0};
    /* verilator lint_on UNUSEDSIGNAL */

    assign busy_o   = 1'b0;
    assign done_o   = 1'b1;
    assign result_o = is_high_mul(operation_i) ? product_comb[63:32] : product_comb[31:0];
  end else begin : g_pipelined
    logic [63:0] product_q;
    logic [4:0]  op_q;
    logic        done_q;

    assign busy_o   = start_i && !done_q;
    assign done_o   = done_q;
    assign result_o = is_high_mul(op_q) ? product_q[63:32] : product_q[31:0];

    always_ff @(posedge clk_i) begin
      if (!rst_ni) begin
        done_q    <= 1'b0;
        product_q <= 64'b0;
        op_q      <= 5'b0;
      end else if (flush_i) begin
        done_q    <= 1'b0;
        product_q <= 64'b0;
        op_q      <= 5'b0;
      end else if (done_q) begin
        if (result_ack_i) begin
          done_q <= 1'b0;
        end
      end else if (start_i) begin
        done_q    <= 1'b1;
        product_q <= product_comb[63:0];
        op_q      <= operation_i;
      end
    end
  end

endmodule
