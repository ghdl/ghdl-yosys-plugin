#!/bin/sh

topdir=../..
. $topdir/testenv.sh

run_yosys -q -p "ghdl blinky.vhdl -e; write_verilog syn_blinky.v"
fgrep -q '.CLKFBOUT_MULT_F(10.625000),' syn_blinky.v
fgrep -q '.CLKIN1_PERIOD(10.000000),' syn_blinky.v

echo OK
