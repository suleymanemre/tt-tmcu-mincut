`timescale 1ns/1ps
// Early-out restoring divide/rem unit for RV32M.
// Features:
// - Fast 1-cycle early completion for: div-by-zero, signed overflow, a==0, |a| < |b|, and |b|==1.
// - CLZ (Leading Zero Count) acceleration: skips leading zeros of operand_a, executing only
//   (32 - clz(a)) iteration cycles instead of fixed 32 cycles.
`include "tmcu_defs.svh"

module tmcu_div (
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
  typedef enum logic [1:0] {
    DIV_IDLE  = 2'd0,
    DIV_RUN   = 2'd1,
    DIV_DONE  = 2'd2
  } state_e;

  state_e        state_q;
  logic [4:0]    op_q;
  logic [31:0]   quotient_q;
  logic [31:0]   remainder_q;
  logic [31:0]   abs_b_q;
  logic [5:0]    step_q;
  logic          a_neg_q;
  logic          b_neg_q;
  logic          fast_result_q;
  logic [31:0]   result_q;

  logic [31:0] quot_next;
  logic [31:0] rem_next;
  logic [31:0] signed_quot;
  logic [31:0] signed_rem;

  function automatic logic is_rem_op(input logic [4:0] op);
    return (op == `TMCU_ALU_REM) || (op == `TMCU_ALU_REMU);
  endfunction

  function automatic logic is_unsigned_op(input logic [4:0] op);
    return (op == `TMCU_ALU_DIVU) || (op == `TMCU_ALU_REMU);
  endfunction

  function automatic logic [31:0] abs32(input logic [31:0] v, input logic signed_mode);
    if (signed_mode && v[31]) return (~v + 32'd1);
    return v;
  endfunction

  function automatic logic [5:0] clz32(input logic [31:0] v);
    logic [5:0] count;
    logic [31:0] tmp;
    count = 6'd0;
    tmp = v;
    if (tmp[31:16] == 16'b0) begin count = count + 6'd16; tmp = tmp << 16; end
    if (tmp[31:24] == 8'b0)  begin count = count + 6'd8;  tmp = tmp << 8;  end
    if (tmp[31:28] == 4'b0)  begin count = count + 6'd4;  tmp = tmp << 4;  end
    if (tmp[31:30] == 2'b0)  begin count = count + 6'd2;  tmp = tmp << 2;  end
    if (tmp[31]    == 1'b0)  begin count = count + 6'd1; end
    return count;
  endfunction

  always_comb begin
    logic [31:0] rem_shift;
    logic [31:0] quot_shift;
    rem_shift   = (remainder_q << 1) | 32'(quotient_q[31]);
    quot_shift  = quotient_q << 1;
    quot_next   = quot_shift;
    rem_next    = rem_shift;
    if (rem_shift >= abs_b_q) begin
      rem_next  = rem_shift - abs_b_q;
      quot_next = quot_shift | 32'd1;
    end
  end

  always_comb begin
    signed_quot = quotient_q;
    signed_rem  = remainder_q;
    if (!fast_result_q && !is_unsigned_op(op_q)) begin
      if (a_neg_q) signed_rem = (~remainder_q + 32'd1);
      if (a_neg_q ^ b_neg_q) signed_quot = (~quotient_q + 32'd1);
    end
    if (fast_result_q) begin
      // Div-by-zero and INT_MIN / -1 already store the final values.
      result_q = is_rem_op(op_q) ? remainder_q : quotient_q;
    end else begin
      result_q = is_rem_op(op_q) ? signed_rem : signed_quot;
    end
  end

  assign busy_o  = (state_q != DIV_IDLE);
  assign done_o  = (state_q == DIV_DONE);
  assign result_o = result_q;

  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      state_q         <= DIV_IDLE;
      op_q            <= 5'b0;
      quotient_q      <= 32'b0;
      remainder_q     <= 32'b0;
      abs_b_q         <= 32'b0;
      step_q          <= 6'b0;
      a_neg_q         <= 1'b0;
      b_neg_q         <= 1'b0;
      fast_result_q   <= 1'b0;
    end else if (flush_i) begin
      state_q         <= DIV_IDLE;
      fast_result_q   <= 1'b0;
    end else begin
      unique case (state_q)
        DIV_IDLE: begin
          if (start_i) begin
            logic [31:0] abs_a;
            logic [31:0] abs_b;
            logic [5:0]  clz_a;

            op_q    <= operation_i;
            a_neg_q <= operand_a_i[31] && !is_unsigned_op(operation_i);
            b_neg_q <= operand_b_i[31] && !is_unsigned_op(operation_i);

            abs_a = abs32(operand_a_i, !is_unsigned_op(operation_i));
            abs_b = abs32(operand_b_i, !is_unsigned_op(operation_i));
            clz_a = clz32(abs_a);

            if (operand_b_i == 32'b0) begin
              // Division by zero
              quotient_q      <= 32'hFFFF_FFFF;
              remainder_q     <= operand_a_i;
              fast_result_q   <= 1'b1;
              state_q         <= DIV_DONE;
            end else if (!is_unsigned_op(operation_i) &&
                         (operand_a_i == 32'h8000_0000) &&
                         (operand_b_i == 32'hFFFF_FFFF)) begin
              // Overflow: INT_MIN / -1
              if (is_rem_op(operation_i)) begin
                quotient_q  <= 32'b0;
                remainder_q <= 32'b0;
              end else begin
                quotient_q  <= 32'h8000_0000;
                remainder_q <= 32'b0;
              end
              fast_result_q <= 1'b1;
              state_q       <= DIV_DONE;
            end else if (abs_a == 32'b0) begin
              // Dividend is 0: quotient=0, remainder=0
              quotient_q    <= 32'b0;
              remainder_q   <= 32'b0;
              fast_result_q <= 1'b1;
              state_q       <= DIV_DONE;
            end else if (abs_a < abs_b) begin
              // |a| < |b|: quotient=0, remainder=a
              quotient_q    <= 32'b0;
              remainder_q   <= abs_a;
              fast_result_q <= 1'b0;
              state_q       <= DIV_DONE;
            end else if (abs_b == 32'd1) begin
              // |b| == 1: quotient=|a|, remainder=0
              quotient_q    <= abs_a;
              remainder_q   <= 32'b0;
              fast_result_q <= 1'b0;
              state_q       <= DIV_DONE;
            end else begin
              // General restoring division with CLZ early skip
              fast_result_q <= 1'b0;
              quotient_q    <= abs_a << clz_a;
              remainder_q   <= 32'b0;
              abs_b_q       <= abs_b;
              step_q        <= clz_a;
              state_q       <= DIV_RUN;
            end
          end
        end

        DIV_RUN: begin
          quotient_q  <= quot_next;
          remainder_q <= rem_next;
          if (step_q == 6'd31) begin
            state_q <= DIV_DONE;
          end else begin
            step_q <= step_q + 6'd1;
          end
        end

        DIV_DONE: begin
          if (result_ack_i) begin
            state_q       <= DIV_IDLE;
            fast_result_q <= 1'b0;
          end
        end

        default: begin
        end
      endcase
    end
  end
endmodule
