#!/bin/sh

topdir=../..
. $topdir/testenv.sh

run_yosys -q -p "ghdl bootrom.vhdl -e bootrom; memory_bram -rules +/ecp5/brams.txt"

echo OK
