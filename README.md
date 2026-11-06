# TMCU → Tiny Tapeout (sky130) min-cut

Self-contained [ttsky-verilog-template](https://github.com/TinyTapeout/ttsky-verilog-template)
tree for measuring how much area a stripped TMCU SoC needs on sky130.

## Min-cut defaults (`src/tt_um_suleymanemre_tmcu.sv`)

- RV32E (16 GPRs) + C extension off (always 32-bit fetch)
- 28-bit `mcycle` / `minstret` (`COUNTER_WIDTH=28`)
- 16-word IMEM + 16-word DMEM
- GPIO only (8-bit)
- No AXI, CLINT, PLIC, UART, TIMER, MONITOR
- No MUL/DIV, branch predictor, or shadow GPR bank
- `info.yaml` tiles start at **8×2** (shrink after GDS utilization is known)

## Workflow

From this directory (`integrations/tinytapeout`):

```sh
./sync_rtl.sh          # copy RTL from ../../rtl into src/ + refresh file lists
```

### GitHub GDS (recommended)

Tiny Tapeout Actions expect this folder as the **repository root**.

1. Push `integrations/tinytapeout` to its own GitHub repo (or subtree-split).
2. Enable Actions + Pages.
3. On push, `gds` workflow runs LibreLane (sky130A).
4. Inspect utilization / die area in the GDS artifacts and viewer.
5. If place/route fails, raise `tiles` (already 8×2) or cut more logic; if
   utilization is low, try `6x2` → `4x2` → …

Rename `top_module` to `tt_um_<githubuser>_tmcu` before a real shuttle submit.

### Local harden

Follow https://tinytapeout.com/guides/local-hardening/ from this directory after
`./sync_rtl.sh`.

### Re-sync after RTL edits

```sh
./sync_rtl.sh
git add src info.yaml test/Makefile
```

## Pinout

| Pins | Function |
|------|----------|
| `uio[7:0]` | GPIO in/out/oe |
| `uo[7:0]`  | GPIO out mirror (LEDs) |
| `ui[7:0]`  | unused |
| `clk` / `rst_n` / `ena` | TT standard |

## Notes

- Memories become flip-flops on TT (no OpenRAM macros) — keep `MEM_WORDS` tiny.
- Software target: `-march=rv32e -mabi=ilp32e` (no C, no M).
- First GDS may still be large: the 5-stage core + CSR/trap dominate.
- cocotb RTL sim prefers Verilator (`test/Makefile`); Icarus does not parse packages.
