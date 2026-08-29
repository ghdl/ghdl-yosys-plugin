#!/bin/sh

topdir=../..
. $topdir/testenv.sh

run_yosys -q -p "ghdl variable_srl.vhdl -e; \
  select -assert-count 1 t:\$shiftx; \
  select -assert-count 0 t:\$bmux; \
  synth_xilinx -family xc6s -top variable_srl; \
  select -assert-count 1 t:SRL16E; \
  select -assert-count 0 t:FDRE"

echo OK
