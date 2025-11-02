#!/bin/sh

topdir=../..
. $topdir/testenv.sh

run_yosys -q -p "ghdl bootrom.vhdl -e bootrom; synth_ecp5 -top BootROM"

echo OK
