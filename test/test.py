# SPDX-FileCopyrightText: © 2024 Tiny Tapeout / TMCU
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_reset_smoke(dut):
    """Bring the min-cut SoC out of reset; IMEM is empty so no functional ISA check."""
    clock = Clock(dut.clk, 40, unit="ns")
    cocotb.start_soon(clock.start())

    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 50)

    # Outputs must be driven (not X) after reset release.
    assert dut.uo_out.value.is_resolvable
    assert dut.uio_out.value.is_resolvable
    assert dut.uio_oe.value.is_resolvable
