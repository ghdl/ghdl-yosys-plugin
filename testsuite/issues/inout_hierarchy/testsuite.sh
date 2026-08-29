#!/bin/sh

topdir=../..
. $topdir/testenv.sh

run_yosys -q -p "ghdl --keep-hierarchy=no --std=08 inout_hierarchy.vhdl -e inout_top; \
  tribuf -logic; deminout; opt; \
  select -module inout_top; \
  select -assert-count 1 i:pads; \
  select -assert-count 1 o:pads; \
  write_rtlil inout_hierarchy.il"

fgrep -q 'wire width 4 inout' inout_hierarchy.il
fgrep -q 'connect \sense \pads' inout_hierarchy.il

rm -f inout_hierarchy.il

echo OK
