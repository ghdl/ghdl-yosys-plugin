#!/bin/sh

topdir=../..
. $topdir/testenv.sh

run_yosys -q -p "ghdl dff01.vhdl -e; hierarchy -check -top dff01"

clean
echo OK
