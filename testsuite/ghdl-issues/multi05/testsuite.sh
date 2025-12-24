#!/bin/sh

topdir=../..
. $topdir/testenv.sh

#run_yosys -p 'ghdl sub.vhdl top.v -e; hierarchy'

run_yosys -p 'ghdl -read sub.vhdl; read_verilog top.v; hierarchy -top top; write_verilog syn_top.v'

echo OK
