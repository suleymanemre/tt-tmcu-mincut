`timescale 1ns/1ps
module tmcu_pipeline_reg #(
  parameter int unsigned WIDTH = 32
) (
  input  logic             clk_i,
  input  logic             rst_ni,
  input  logic             stall_i,
  input  logic             flush_i,
  input  logic             valid_i,
  input  logic [WIDTH-1:0] data_i,
  output logic             valid_o,
  output logic [WIDTH-1:0] data_o
);
  // Öncelik: reset > flush > stall > normal aktarım.
  // Flush, stalled bir aşamayı da geçersiz kılar; redirect/trap durumunda eski
  // instruction'ın pipeline'da tutulmasını engeller.
  always_ff @(posedge clk_i) begin
    if (!rst_ni) begin
      valid_o <= 1'b0;
      data_o  <= '0;
    end else if (flush_i) begin
      valid_o <= 1'b0;
      data_o  <= '0;
    end else if (!stall_i) begin
      valid_o <= valid_i;
      data_o  <= data_i;
    end
  end
endmodule
