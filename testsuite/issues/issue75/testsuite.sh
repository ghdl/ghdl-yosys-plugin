#!/bin/sh

topdir=../..
. $topdir/testenv.sh

run_yosys -q -p "ghdl top.vhdl -e top; hierarchy -check -top top"

clean
echo OK
