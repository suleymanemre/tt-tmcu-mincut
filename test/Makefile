# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

# defaults — Verilator preferred (design uses SystemVerilog packages).
SIM ?= verilator
FST ?= -fst
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../src
PROJECT_SOURCES = pkg/tmcu_pkg.sv core/tmcu_regfile.sv core/tmcu_csr_trap.sv core/tmcu_immediate_gen.sv core/tmcu_alu.sv core/tmcu_mul.sv core/tmcu_div.sv core/tmcu_branch_compare.sv core/tmcu_branch_predictor.sv core/tmcu_decompress.sv core/tmcu_decoder.sv core/tmcu_hazard_unit.sv core/tmcu_pipeline_reg.sv core/tmcu_perf_probe.sv core/tmcu_core.sv tmcu_top.sv memory/tmcu_native_bram.sv memory/tmcu_imem.sv memory/tmcu_dmem.sv interrupt/tmcu_clint.sv interrupt/tmcu_plic.sv interconnect/tmcu_request_router.sv interconnect/tmcu_native_to_axi4lite.sv peripheral/tmcu_gpio.sv peripheral/tmcu_timer.sv peripheral/tmcu_uart.sv peripheral/tmcu_monitor.sv soc/tmcu_soc.sv tt_um_suleymanemre_tmcu.sv

ifneq ($(GATES),yes)

SIM_BUILD				= sim_build/rtl
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))

else

SIM_BUILD				= sim_build/gl
COMPILE_ARGS    += -DGL_TEST
COMPILE_ARGS    += -DFUNCTIONAL
COMPILE_ARGS    += -DUSE_POWER_PINS
COMPILE_ARGS    += -DSIM
COMPILE_ARGS    += -DUNIT_DELAY=\#1
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

endif

COMPILE_ARGS 		+= -I$(SRC_DIR) -I$(SRC_DIR)/include
# Verilator 5.036+ promotes WIDTH* to fatal by default; TT min-cut uses
# GPIO_WIDTH=8 and small BRAMs that trip WIDTHEXPAND/WIDTHTRUNC. Smoke test
# only needs a buildable sim — keep these as warnings, not hard errors.
EXTRA_ARGS      += --timing -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-fatal

VERILOG_SOURCES += $(PWD)/tb.v
TOPLEVEL = tb

COCOTB_TEST_MODULES = test

include $(shell cocotb-config --makefiles)/Makefile.sim
