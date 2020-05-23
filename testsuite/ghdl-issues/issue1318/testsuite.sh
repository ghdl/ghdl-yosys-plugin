#!/bin/sh

topdir=../..
. $topdir/testenv.sh

run_yosys -q -p "ghdl ram_blk.vhdl -e; write_verilog ram_blk.v"
grep ram_style ram_blk.v
clean

echo OK
