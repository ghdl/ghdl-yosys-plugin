#!/bin/sh

topdir=../..
. $topdir/testenv.sh

run_yosys -p "ghdl --disp-config"

echo OK
