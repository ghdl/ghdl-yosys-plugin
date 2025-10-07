#!/bin/sh

topdir=../..
. $topdir/testenv.sh

run_yosys -q -p "ghdl attr.vhdl -e; write_verilog attr.v"
grep "MY_ENTITY_ATTRIBUTE" attr.v

clean
echo OK
