#!/bin/sh

topdir=../..
. $topdir/testenv.sh

run_yosys -q -p "ghdl blackbox1.vhdl -e; write_verilog blackbox1.v"
fgrep -q "my_blackbox" blackbox1.v

run_yosys -q -p "ghdl blackbox2.vhdl -e; write_verilog blackbox2.v"
fgrep -q ".OUT(" blackbox2.v

run_yosys -q -p "ghdl blackbox3.vhdl -e; write_verilog blackbox3.v"
fgrep -q "\lib__cell__box2.3 " blackbox3.v

clean
echo OK
