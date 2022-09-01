#!/bin/sh

topdir=../..
. $topdir/testenv.sh

run_yosys -q -p "ghdl bootrom.vhdl -e bootrom; memory_libmap -lib +/ecp5/lutrams.txt -lib +/ecp5/brams.txt"

echo OK
