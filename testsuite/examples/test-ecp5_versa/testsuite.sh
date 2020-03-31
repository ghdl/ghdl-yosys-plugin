#!/bin/sh

topdir=../..
. $topdir/testenv.sh

top=../../..
src=$top/examples/ecp5_versa

VHDL_SYN_FILES="$src/versa_ecp5_top.vhdl \
 $src/pll_mac.vhd \
 $src/soc_iomap_pkg.vhdl \
 $src/uart.vhdl \
 $src/uart_tx.vhdl \
 $src/uart_rx.vhdl \
 $src/fifobuf.vhdl"

VERILOG_FILES="\
 $top/library/wrapper/primitives.v \
 $top/library/wrapper/wrapper.v \
 $top/library/wrapper/bram.v
"

FREQ=25000000

run_yosys -p "ghdl -gCLK_FREQUENCY=$FREQ --work=ecp5um $top/library/ecp5u/components.vhdl --work=work $VHDL_SYN_FILES -e; read_verilog $VERILOG_FILES; synth_ecp5 -top versa_ecp5_top -json top_ecp5_top.json" -l report.txt -q
