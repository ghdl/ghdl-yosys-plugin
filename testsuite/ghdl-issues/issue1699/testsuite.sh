#!/bin/sh

topdir=../..
. $topdir/testenv.sh

run_yosys -p "ghdl --std=08 test2.vhdl -e; write_verilog test2.v"

clean
echo OK
