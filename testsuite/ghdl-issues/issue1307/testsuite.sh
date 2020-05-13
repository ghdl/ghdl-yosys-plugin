#!/bin/sh

topdir=../..
. $topdir/testenv.sh

run_yosys -q -p "ghdl hdmi_design.vhd hdmi_io.vhd conversion_to_RGB.vhd -e; synth_xilinx -flatten -edif hdmi_design.edif"

echo OK
