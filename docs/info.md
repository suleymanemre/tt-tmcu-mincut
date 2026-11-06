<!---
Tiny Tapeout datasheet source for the TMCU minimum-area sky130 cut.
-->

## How it works

This project is a **minimum-area cut** of [TMCU](https://github.com/), an RV32IMC
5-stage RISC-V microcontroller, prepared for Tiny Tapeout sky130 area experiments.

Default parameters in `tt_um_suleymanemre_tmcu`:

| Feature | Setting |
|---------|---------|
| IMEM / DMEM | 16 words each (FF-backed) |
| GPIO | 8-bit on `uio` (mirrored on `uo`) |
| AXI / CLINT / PLIC / UART / TIMER / MONITOR | off |
| Multiply / Divide / Branch predictor / Shadow GPR | off |

Reset vector and IMEM base remain `0x8000_0000`. DMEM is at `0x2000_0000`.
GPIO MMIO is at `0x4000_2000`.

With empty IMEM the core fetches zeros after reset; this cut is intended first
for **GDS / utilization** measurements, not a full software demo.

## How to test

1. Release `rst_n` with `ena=1` and a free-running `clk`.
2. After reset, `uo_out` / `uio_out` / `uio_oe` must be driven (not X).
3. For a functional blink, preload a tiny program into IMEM (via `IMEM_INIT_FILE`
   in a local rebuild) that writes the GPIO data register at `0x4000_2000`.

RTL smoke:

```sh
./sync_rtl.sh
cd test && make
```

## External hardware

Optional LEDs on `uo[7:0]` / `uio[7:0]` through current-limiting resistors.
No UART or SPI flash in the default min-cut.
