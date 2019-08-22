set -e

ROOT="$(pwd)/.."

rm -rf build
mkdir -p build
cd build

ghdl -a "$ROOT"/hdl/uart_rx.vhd
ghdl -a "$ROOT"/hdl/uart_tx.vhd
ghdl -a "$ROOT"/hdl/uart_top.vhd
yosys -m ghdl -p 'ghdl uart_top; synth_ice40 -json uart_top.json'
nextpnr-ice40 --hx1k --json uart_top.json --pcf ../constraints/uart.pcf --asc uart_top.asc --pcf-allow-unconstrained
icepack uart_top.asc uart_top.bin
iceprog uart_top.bin
