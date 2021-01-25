#!/bin/sh

topdir=../..
. $topdir/testenv.sh

run_yosys -q -p "ghdl --std=08 exp.vhdl -e; write_rtlil exp.il"
fgrep 'cell $ff' exp.il

clean
echo OK
