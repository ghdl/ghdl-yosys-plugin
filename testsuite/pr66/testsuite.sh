#!/bin/sh

topdir=..
. $topdir/testenv.sh

run_yosys -p "ghdl vector.vhdl -e vector; opt; dump -o vector.il"

grep -q 'connect \\v 63' vector.il || exit 1

clean
