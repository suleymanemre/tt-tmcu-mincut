/*
 * Tiny Tapeout wrapper for a minimum-area TMCU SoC cut.
 *
 * Default configuration (area-first):
 *   - 16-word IMEM + 16-word DMEM (FF-backed on sky130)
 *   - GPIO only (8-bit on uio)
 *   - No AXI / CLINT / PLIC / UART / TIMER / MONITOR
 *   - No M-extension, branch predictor, or shadow GPR bank
 *
 * SPDX-License-Identifier: Apache-2.0
 */
`default_nettype none

module tt_um_suleymanemre_tmcu (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
  localparam int unsigned MEM_WORDS  = 16;
  localparam int unsigned GPIO_WIDTH = 8;

  logic [GPIO_WIDTH-1:0] gpio_out;
  logic [GPIO_WIDTH-1:0] gpio_oe;

  // Tie-offs / unused SoC sidebands (features disabled below).
  logic        uart_tx_unused;
  logic [31:0] axi_awaddr_unused;
  logic        axi_awvalid_unused;
  logic [2:0]  axi_awprot_unused;
  logic [31:0] axi_wdata_unused;
  logic [3:0]  axi_wstrb_unused;
  logic        axi_wvalid_unused;
  logic        axi_bready_unused;
  logic [31:0] axi_araddr_unused;
  logic        axi_arvalid_unused;
  logic [2:0]  axi_arprot_unused;
  logic        axi_rready_unused;
  logic        trace_valid_unused;
  logic [31:0] trace_pc_unused;
  logic [31:0] trace_instruction_unused;
  logic        trace_rd_write_unused;
  logic [4:0]  trace_rd_addr_unused;
  logic [31:0] trace_rd_data_unused;
  logic        trace_mem_valid_unused;
  logic        trace_mem_write_unused;
  logic [31:0] trace_mem_addr_unused;
  logic [31:0] trace_mem_wdata_unused;
  logic [3:0]  trace_mem_wstrb_unused;
  logic        trace_trap_unused;
  logic [31:0] trace_cause_unused;
  logic [31:0] dbg_fetch_pc_unused;
  logic [31:0] dbg_if_pc_unused;
  logic        dbg_if_valid_unused;
  logic [31:0] dbg_ex_pc_unused;
  logic        dbg_ex_valid_unused;
  logic [31:0] dbg_mem_pc_unused;
  logic        dbg_mem_valid_unused;
  logic [31:0] dbg_wb_pc_unused;
  logic        dbg_wb_valid_unused;
  logic        dbg_rf_we_unused;
  logic [4:0]  dbg_rf_waddr_unused;
  logic [31:0] dbg_rf_wdata_unused;
  logic [31:0] dbg_csr_mstatus_unused;
  logic [31:0] dbg_csr_mie_unused;
  logic [31:0] dbg_csr_mtvec_unused;
  logic [31:0] dbg_csr_mscratch_unused;
  logic [31:0] dbg_csr_mepc_unused;
  logic [31:0] dbg_csr_mcause_unused;
  logic [31:0] dbg_csr_mtval_unused;
  logic [31:0] dbg_csr_mip_unused;
  logic [31:0] dbg_csr_mcycle_unused;
  logic [31:0] dbg_csr_mcycleh_unused;
  logic [31:0] dbg_csr_minstret_unused;
  logic [31:0] dbg_csr_minstreth_unused;

  // Tiny on-chip windows: IMEM @ 0x8000_0000, DMEM @ 0x2000_0000.
  // Masks cover a 64-byte (16-word) aperture.
  tmcu_soc #(
      .RESET_VECTOR       (32'h8000_0000),
      .MTVEC_RESET        (32'h8000_0000),
      .SHADOW_BANK_ENABLE (1'b0),
      .AXI_ENABLE         (1'b0),
      .CLINT_ENABLE       (1'b0),
      .PLIC_ENABLE        (1'b0),
      .GPIO_ENABLE        (1'b1),
      .TIMER_ENABLE       (1'b0),
      .UART_ENABLE        (1'b0),
      .MONITOR_ENABLE     (1'b0),
      .MUL_ENABLE         (1'b0),
      .DIV_ENABLE         (1'b0),
      .BP_ENABLE          (1'b0),
      .TRACE_ENABLE       (1'b0),
      .DEBUG_ENABLE       (1'b0),
      .IMEM_WORDS         (MEM_WORDS),
      .DMEM_WORDS         (MEM_WORDS),
      // Keep default PLIC source count so static IRQ mux indices stay in-range
      // even though PLIC_ENABLE=0 removes the controller itself.
      .PLIC_SOURCES       (16),
      .IMEM_BASE          (32'h8000_0000),
      .DMEM_BASE          (32'h2000_0000),
      .DMEM_MASK          (32'hFFFF_FFC0),
      .GPIO_BASE          (32'h4000_2000),
      .GPIO_MASK          (32'hFFFF_F000),
      .GPIO_WIDTH         (GPIO_WIDTH),
      .IMEM_INIT_FILE     (""),
      .DMEM_INIT_FILE     (""),
      .BP_ENTRIES         (2),
      .BP_GSHARE          (1'b0),
      .GHR_WIDTH          (1)
  ) u_soc (
      .clk_i               (clk),
      .rst_ni              (rst_n),
      .ext_irq_i           (1'b0),
      .gpio_in_i           (uio_in),
      .gpio_out_o          (gpio_out),
      .gpio_oe_o           (gpio_oe),
      .uart_tx_o           (uart_tx_unused),
      .uart_rx_i           (1'b1),
      .m_axi_awaddr_o      (axi_awaddr_unused),
      .m_axi_awvalid_o     (axi_awvalid_unused),
      .m_axi_awready_i     (1'b0),
      .m_axi_awprot_o      (axi_awprot_unused),
      .m_axi_wdata_o       (axi_wdata_unused),
      .m_axi_wstrb_o       (axi_wstrb_unused),
      .m_axi_wvalid_o      (axi_wvalid_unused),
      .m_axi_wready_i      (1'b0),
      .m_axi_bresp_i       (2'b0),
      .m_axi_bvalid_i      (1'b0),
      .m_axi_bready_o      (axi_bready_unused),
      .m_axi_araddr_o      (axi_araddr_unused),
      .m_axi_arvalid_o     (axi_arvalid_unused),
      .m_axi_arready_i     (1'b0),
      .m_axi_arprot_o      (axi_arprot_unused),
      .m_axi_rdata_i       (32'b0),
      .m_axi_rresp_i       (2'b0),
      .m_axi_rvalid_i      (1'b0),
      .m_axi_rready_o      (axi_rready_unused),
      .trace_valid_o       (trace_valid_unused),
      .trace_pc_o          (trace_pc_unused),
      .trace_instruction_o (trace_instruction_unused),
      .trace_rd_write_o    (trace_rd_write_unused),
      .trace_rd_addr_o     (trace_rd_addr_unused),
      .trace_rd_data_o     (trace_rd_data_unused),
      .trace_mem_valid_o   (trace_mem_valid_unused),
      .trace_mem_write_o   (trace_mem_write_unused),
      .trace_mem_addr_o    (trace_mem_addr_unused),
      .trace_mem_wdata_o   (trace_mem_wdata_unused),
      .trace_mem_wstrb_o   (trace_mem_wstrb_unused),
      .trace_trap_o        (trace_trap_unused),
      .trace_cause_o       (trace_cause_unused),
      .dbg_fetch_pc_o      (dbg_fetch_pc_unused),
      .dbg_if_pc_o         (dbg_if_pc_unused),
      .dbg_if_valid_o      (dbg_if_valid_unused),
      .dbg_ex_pc_o         (dbg_ex_pc_unused),
      .dbg_ex_valid_o      (dbg_ex_valid_unused),
      .dbg_mem_pc_o        (dbg_mem_pc_unused),
      .dbg_mem_valid_o     (dbg_mem_valid_unused),
      .dbg_wb_pc_o         (dbg_wb_pc_unused),
      .dbg_wb_valid_o      (dbg_wb_valid_unused),
      .dbg_rf_we_o         (dbg_rf_we_unused),
      .dbg_rf_waddr_o      (dbg_rf_waddr_unused),
      .dbg_rf_wdata_o      (dbg_rf_wdata_unused),
      .dbg_csr_mstatus_o   (dbg_csr_mstatus_unused),
      .dbg_csr_mie_o       (dbg_csr_mie_unused),
      .dbg_csr_mtvec_o     (dbg_csr_mtvec_unused),
      .dbg_csr_mscratch_o  (dbg_csr_mscratch_unused),
      .dbg_csr_mepc_o      (dbg_csr_mepc_unused),
      .dbg_csr_mcause_o    (dbg_csr_mcause_unused),
      .dbg_csr_mtval_o     (dbg_csr_mtval_unused),
      .dbg_csr_mip_o       (dbg_csr_mip_unused),
      .dbg_csr_mcycle_o    (dbg_csr_mcycle_unused),
      .dbg_csr_mcycleh_o   (dbg_csr_mcycleh_unused),
      .dbg_csr_minstret_o  (dbg_csr_minstret_unused),
      .dbg_csr_minstreth_o (dbg_csr_minstreth_unused)
  );

  assign uio_out = gpio_out;
  assign uio_oe  = gpio_oe;
  assign uo_out  = gpio_out;

  wire _unused = &{ena, ui_in, uart_tx_unused,
                   axi_awaddr_unused, axi_awvalid_unused, axi_awprot_unused,
                   axi_wdata_unused, axi_wstrb_unused, axi_wvalid_unused,
                   axi_bready_unused, axi_araddr_unused, axi_arvalid_unused,
                   axi_arprot_unused, axi_rready_unused,
                   trace_valid_unused, trace_pc_unused, trace_instruction_unused,
                   trace_rd_write_unused, trace_rd_addr_unused, trace_rd_data_unused,
                   trace_mem_valid_unused, trace_mem_write_unused, trace_mem_addr_unused,
                   trace_mem_wdata_unused, trace_mem_wstrb_unused, trace_trap_unused,
                   trace_cause_unused, dbg_fetch_pc_unused, dbg_if_pc_unused,
                   dbg_if_valid_unused, dbg_ex_pc_unused, dbg_ex_valid_unused,
                   dbg_mem_pc_unused, dbg_mem_valid_unused, dbg_wb_pc_unused,
                   dbg_wb_valid_unused, dbg_rf_we_unused, dbg_rf_waddr_unused,
                   dbg_rf_wdata_unused, dbg_csr_mstatus_unused, dbg_csr_mie_unused,
                   dbg_csr_mtvec_unused, dbg_csr_mscratch_unused, dbg_csr_mepc_unused,
                   dbg_csr_mcause_unused, dbg_csr_mtval_unused, dbg_csr_mip_unused,
                   dbg_csr_mcycle_unused, dbg_csr_mcycleh_unused,
                   dbg_csr_minstret_unused, dbg_csr_minstreth_unused, 1'b0};

endmodule
