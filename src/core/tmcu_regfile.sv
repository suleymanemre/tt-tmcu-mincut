`timescale 1ns/1ps
module tmcu_regfile #(
  parameter bit          SHADOW_BANK_ENABLE = 1'b1,
  // RV32I: 32 (x0..x31, x0 hardwired). RV32E: 16 (x0..x15).
  parameter int unsigned REG_COUNT          = 32
) (
  input  logic        clk_i,
  input  logic        bank_select_i,

  input  logic [4:0]  rs1_addr_i,
  output logic [31:0] rs1_data_o,
  input  logic [4:0]  rs2_addr_i,
  output logic [31:0] rs2_data_o,

  input  logic        rd_write_i,
  input  logic [4:0]  rd_addr_i,
  input  logic [31:0] rd_data_i
);
  // Physical storage is x1..(REG_COUNT-1). x0 is hard-wired zero.
  // Addresses >= REG_COUNT read as zero and ignore writes (RV32E software
  // never uses them; hardware stays small without extra illegal-instr traps).
  localparam int unsigned PHYS_MAX = (REG_COUNT <= 1) ? 1 : (REG_COUNT - 1);

  logic [31:0] normal_registers_q [1:PHYS_MAX];
  logic        active_shadow_bank;
  logic        rs1_in_range;
  logic        rs2_in_range;
  logic        rd_in_range;

  assign active_shadow_bank = SHADOW_BANK_ENABLE && bank_select_i;
  assign rs1_in_range = (rs1_addr_i != 5'd0) && (rs1_addr_i <= PHYS_MAX[4:0]);
  assign rs2_in_range = (rs2_addr_i != 5'd0) && (rs2_addr_i <= PHYS_MAX[4:0]);
  assign rd_in_range  = (rd_addr_i  != 5'd0) && (rd_addr_i  <= PHYS_MAX[4:0]);

  if (SHADOW_BANK_ENABLE) begin : g_shadow
    logic [31:0] shadow_registers_q [1:PHYS_MAX];

    always_comb begin
      rs1_data_o = 32'b0;
      if (rs1_in_range) begin
        rs1_data_o = active_shadow_bank
          ? shadow_registers_q[rs1_addr_i]
          : normal_registers_q[rs1_addr_i];
      end
    end

    always_comb begin
      rs2_data_o = 32'b0;
      if (rs2_in_range) begin
        rs2_data_o = active_shadow_bank
          ? shadow_registers_q[rs2_addr_i]
          : normal_registers_q[rs2_addr_i];
      end
    end

    always_ff @(posedge clk_i) begin
      if (rd_write_i && rd_in_range) begin
        if (active_shadow_bank) begin
          shadow_registers_q[rd_addr_i] <= rd_data_i;
        end else begin
          normal_registers_q[rd_addr_i] <= rd_data_i;
        end
      end
    end
  end else begin : g_no_shadow
    always_comb begin
      rs1_data_o = 32'b0;
      if (rs1_in_range) begin
        rs1_data_o = normal_registers_q[rs1_addr_i];
      end
    end

    always_comb begin
      rs2_data_o = 32'b0;
      if (rs2_in_range) begin
        rs2_data_o = normal_registers_q[rs2_addr_i];
      end
    end

    always_ff @(posedge clk_i) begin
      if (rd_write_i && rd_in_range) begin
        normal_registers_q[rd_addr_i] <= rd_data_i;
      end
    end
  end
endmodule
