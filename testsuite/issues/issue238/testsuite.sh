#!/bin/sh

topdir=../..
. $topdir/testenv.sh

run_yosys -q -p "ghdl top.vhdl -e; write_verilog top.v"

sed -i -e '1d' top.v

cmp top.v top.ref

echo OK
