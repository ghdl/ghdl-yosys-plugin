#!/bin/sh

topdir=../..
. $topdir/testenv.sh

run_yosys -q -p "ghdl cell1.vhdl -e cell1; ghdl cell2.vhdl -e cell2"

clean
echo OK
