`timescale 1ns/1ps
`include "tmcu_defs.svh"

package tmcu_pkg;
  localparam int unsigned XLEN            = 32;
  localparam int unsigned REG_COUNT       = 32;
  localparam int unsigned REG_INDEX_WIDTH = $clog2(REG_COUNT);
  localparam int unsigned BYTE_COUNT      = XLEN / 8;

  typedef logic [XLEN-1:0]            word_t;
  typedef logic [XLEN-1:0]            addr_t;
  typedef logic [REG_INDEX_WIDTH-1:0] reg_idx_t;
  typedef logic [BYTE_COUNT-1:0]      byte_strobe_t;

  typedef enum logic [4:0] {
    ALU_ADD    = `TMCU_ALU_ADD,
    ALU_SUB    = `TMCU_ALU_SUB,
    ALU_SLL    = `TMCU_ALU_SLL,
    ALU_SLT    = `TMCU_ALU_SLT,
    ALU_SLTU   = `TMCU_ALU_SLTU,
    ALU_XOR    = `TMCU_ALU_XOR,
    ALU_SRL    = `TMCU_ALU_SRL,
    ALU_SRA    = `TMCU_ALU_SRA,
    ALU_OR     = `TMCU_ALU_OR,
    ALU_AND    = `TMCU_ALU_AND,
    ALU_PASS_A = `TMCU_ALU_PASS_A,
    ALU_PASS_B = `TMCU_ALU_PASS_B,
    // M extension
    ALU_MUL    = `TMCU_ALU_MUL,
    ALU_MULH   = `TMCU_ALU_MULH,
    ALU_MULHSU = `TMCU_ALU_MULHSU,
    ALU_MULHU  = `TMCU_ALU_MULHU,
    ALU_DIV    = `TMCU_ALU_DIV,
    ALU_DIVU   = `TMCU_ALU_DIVU,
    ALU_REM    = `TMCU_ALU_REM,
    ALU_REMU   = `TMCU_ALU_REMU
  } alu_op_e;

  typedef enum logic [2:0] {
    BRANCH_NONE = `TMCU_BRANCH_NONE,
    BRANCH_EQ   = `TMCU_BRANCH_EQ,
    BRANCH_NE   = `TMCU_BRANCH_NE,
    BRANCH_LT   = `TMCU_BRANCH_LT,
    BRANCH_GE   = `TMCU_BRANCH_GE,
    BRANCH_LTU  = `TMCU_BRANCH_LTU,
    BRANCH_GEU  = `TMCU_BRANCH_GEU
  } branch_op_e;

  typedef enum logic [2:0] {
    IMM_NONE = `TMCU_IMM_NONE,
    IMM_I    = `TMCU_IMM_I,
    IMM_S    = `TMCU_IMM_S,
    IMM_B    = `TMCU_IMM_B,
    IMM_U    = `TMCU_IMM_U,
    IMM_J    = `TMCU_IMM_J,
    IMM_Z    = `TMCU_IMM_Z
  } immediate_format_e;

  typedef enum logic [1:0] {
    OPERAND_A_RS1  = `TMCU_OPERAND_A_RS1,
    OPERAND_A_PC   = `TMCU_OPERAND_A_PC,
    OPERAND_A_ZERO = `TMCU_OPERAND_A_ZERO
  } operand_a_select_e;

  typedef enum logic {
    OPERAND_B_RS2 = `TMCU_OPERAND_B_RS2,
    OPERAND_B_IMM = `TMCU_OPERAND_B_IMM
  } operand_b_select_e;

  typedef enum logic [2:0] {
    WB_NONE    = `TMCU_WB_NONE,
    WB_ALU     = `TMCU_WB_ALU,
    WB_MEMORY  = `TMCU_WB_MEMORY,
    WB_PC_NEXT = `TMCU_WB_PC_NEXT,
    WB_CSR     = `TMCU_WB_CSR
  } writeback_select_e;

  typedef enum logic [1:0] {
    MEMORY_BYTE = `TMCU_MEMORY_BYTE,
    MEMORY_HALF = `TMCU_MEMORY_HALF,
    MEMORY_WORD = `TMCU_MEMORY_WORD
  } memory_size_e;

  typedef enum logic [3:0] {
    SYSTEM_NONE    = `TMCU_SYSTEM_NONE,
    SYSTEM_ECALL   = `TMCU_SYSTEM_ECALL,
    SYSTEM_EBREAK  = `TMCU_SYSTEM_EBREAK,
    SYSTEM_MRET    = `TMCU_SYSTEM_MRET,
    SYSTEM_CSR_RW  = `TMCU_SYSTEM_CSR_RW,
    SYSTEM_CSR_RS  = `TMCU_SYSTEM_CSR_RS,
    SYSTEM_CSR_RC  = `TMCU_SYSTEM_CSR_RC,
    SYSTEM_CSR_RWI = `TMCU_SYSTEM_CSR_RWI,
    SYSTEM_CSR_RSI = `TMCU_SYSTEM_CSR_RSI,
    SYSTEM_CSR_RCI = `TMCU_SYSTEM_CSR_RCI
  } system_operation_e;

  typedef struct packed {
    logic         write;
    addr_t        addr;
    word_t        wdata;
    byte_strobe_t wstrb;
  } native_req_t;

  typedef struct packed {
    word_t rdata;
    logic  err;
  } native_rsp_t;

  typedef struct packed {
    logic  valid;
    addr_t pc;
    word_t instruction;
  } if_id_payload_t;

  typedef struct packed {
    logic       valid;
    addr_t      pc;
    word_t      instruction;
    reg_idx_t   rs1;
    reg_idx_t   rs2;
    reg_idx_t   rd;
    word_t      rs1_value;
    word_t      rs2_value;
    word_t      immediate;
    alu_op_e    alu_op;
    branch_op_e branch_op;
  } id_ex_payload_t;
endpackage
