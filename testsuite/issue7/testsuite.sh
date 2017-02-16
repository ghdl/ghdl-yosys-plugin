#!/bin/sh

. ../testenv.sh

analyze ref.vhdl
run_yosys -q -p "ghdl vector ref; write_verilog ref.v"

analyze vector.vhdl
run_yosys -q -p "ghdl vector synth; write_verilog vector.v"

run_yosys -p '
 read_verilog ref.v
 rename vector ref

 read_verilog vector.v
 equiv_make ref vector equiv

 hierarchy -top equiv
 equiv_simple
 equiv_status -assert'

clean
rm -f *.v
