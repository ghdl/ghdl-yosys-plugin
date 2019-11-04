#!/bin/sh

topdir=../..
. $topdir/testenv.sh

run_yosys -Q -q -p "ghdl ref.vhdl -e vector ref; write_verilog ref.v"
run_yosys -Q -q -p "ghdl ref.vhdl vector.vhdl -e vector synth; write_verilog vector.v"

run_yosys -Q -p '
 read_verilog ref.v
 rename vector ref

 read_verilog vector.v
 equiv_make ref vector equiv

 hierarchy -top equiv
 equiv_simple
 equiv_status -assert'

clean
rm -f *.v
