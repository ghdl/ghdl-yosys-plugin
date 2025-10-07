#!/bin/sh

topdir=../..
. $topdir/testenv.sh

run_yosys -q -p "ghdl --std=08 top.vhdl -e; write_verilog exp.v"
fgrep 'LOC = "13"' exp.v > /dev/null

clean
echo OK
