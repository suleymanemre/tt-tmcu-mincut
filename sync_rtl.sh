#!/usr/bin/env bash
# Copy the TMCU RTL needed by the Tiny Tapeout min-cut into ./src and refresh
# info.yaml source_files + test/Makefile PROJECT_SOURCES.
#
# Disabled peripherals (UART/TIMER/…) are still copied so Synlig/LibreLane can
# elaborate generate-if branches; they are not instantiated with the min-cut
# parameters in tt_um_tmcu.sv.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "${ROOT}/../.." && pwd)"
SRC="${ROOT}/src"
RTL="${REPO}/rtl"

mkdir -p \
  "${SRC}/include" \
  "${SRC}/pkg" \
  "${SRC}/core" \
  "${SRC}/memory" \
  "${SRC}/interconnect" \
  "${SRC}/interrupt" \
  "${SRC}/peripheral" \
  "${SRC}/soc"

copy() {
  local rel="$1"
  install -D -m 0644 "${RTL}/${rel}" "${SRC}/${rel}"
}

copy "include/tmcu_defs.svh"
copy "include/tmcu_perf_events.svh"
copy "include/tmcu_monitor_regs.svh"

# tt_tool.py --create-user-config runs Yosys without -I; Yosys only searches
# CWD and the including file's directory. Mirror headers next to consumers.
for hdr_dir in "" pkg core soc peripheral; do
  dest="${SRC}/${hdr_dir}"
  mkdir -p "${dest}"
  install -m 0644 "${RTL}/include/tmcu_defs.svh" "${dest}/tmcu_defs.svh"
  install -m 0644 "${RTL}/include/tmcu_perf_events.svh" "${dest}/tmcu_perf_events.svh"
  install -m 0644 "${RTL}/include/tmcu_monitor_regs.svh" "${dest}/tmcu_monitor_regs.svh"
done

copy "pkg/tmcu_pkg.sv"
copy "core/tmcu_regfile.sv"
copy "core/tmcu_csr_trap.sv"
copy "core/tmcu_immediate_gen.sv"
copy "core/tmcu_alu.sv"
copy "core/tmcu_mul.sv"
copy "core/tmcu_div.sv"
copy "core/tmcu_branch_compare.sv"
copy "core/tmcu_branch_predictor.sv"
copy "core/tmcu_decompress.sv"
copy "core/tmcu_decoder.sv"
copy "core/tmcu_hazard_unit.sv"
copy "core/tmcu_pipeline_reg.sv"
copy "core/tmcu_perf_probe.sv"
copy "core/tmcu_core.sv"
copy "tmcu_top.sv"
copy "memory/tmcu_native_bram.sv"
copy "memory/tmcu_imem.sv"
copy "memory/tmcu_dmem.sv"
copy "interrupt/tmcu_clint.sv"
copy "interrupt/tmcu_plic.sv"
copy "interconnect/tmcu_request_router.sv"
copy "interconnect/tmcu_native_to_axi4lite.sv"
copy "peripheral/tmcu_gpio.sv"
copy "peripheral/tmcu_timer.sv"
copy "peripheral/tmcu_uart.sv"
copy "peripheral/tmcu_monitor.sv"
copy "soc/tmcu_soc.sv"

SOURCES=(
  "pkg/tmcu_pkg.sv"
  "core/tmcu_regfile.sv"
  "core/tmcu_csr_trap.sv"
  "core/tmcu_immediate_gen.sv"
  "core/tmcu_alu.sv"
  "core/tmcu_mul.sv"
  "core/tmcu_div.sv"
  "core/tmcu_branch_compare.sv"
  "core/tmcu_branch_predictor.sv"
  "core/tmcu_decompress.sv"
  "core/tmcu_decoder.sv"
  "core/tmcu_hazard_unit.sv"
  "core/tmcu_pipeline_reg.sv"
  "core/tmcu_perf_probe.sv"
  "core/tmcu_core.sv"
  "tmcu_top.sv"
  "memory/tmcu_native_bram.sv"
  "memory/tmcu_imem.sv"
  "memory/tmcu_dmem.sv"
  "interrupt/tmcu_clint.sv"
  "interrupt/tmcu_plic.sv"
  "interconnect/tmcu_request_router.sv"
  "interconnect/tmcu_native_to_axi4lite.sv"
  "peripheral/tmcu_gpio.sv"
  "peripheral/tmcu_timer.sv"
  "peripheral/tmcu_uart.sv"
  "peripheral/tmcu_monitor.sv"
  "soc/tmcu_soc.sv"
  "tt_um_suleymanemre_tmcu.sv"
)

python3 - "${ROOT}/info.yaml" "${SOURCES[@]}" <<'PY'
import pathlib, sys, re
info_path = pathlib.Path(sys.argv[1])
sources = sys.argv[2:]
text = info_path.read_text()
block = "  source_files:\n" + "".join(f'    - "{s}"\n' for s in sources)
text2, n = re.subn(
    r"  source_files:\n(?:    - \".*\"\n)+",
    block,
    text,
    count=1,
)
if n != 1:
    raise SystemExit("failed to rewrite source_files in info.yaml")
info_path.write_text(text2)
print(f"updated {info_path} ({len(sources)} sources)")
PY

proj_sources="${SOURCES[*]}"
sed -i "s|^PROJECT_SOURCES = .*|PROJECT_SOURCES = ${proj_sources}|" "${ROOT}/test/Makefile"

echo "Synced ${#SOURCES[@]} RTL sources into ${SRC}"
