#!/bin/sh

topdir=../..
. $topdir/testenv.sh

run_yosys -Q -q -p "ghdl keep.vhdl -e; write_verilog keep.v"

# Check the signal still exists
fgrep -q "wire [2:0] a" keep.v

rm -f *.v
echo OK
