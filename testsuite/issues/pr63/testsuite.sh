#!/bin/sh

topdir=../..
. $topdir/testenv.sh

run_yosys -q -p "ghdl vector.vhdl -e vector; opt; dump -o vector.il"

grep -q 1111000000000000000000000000000000000000000000000000000000010000 vector.il || exit 1

clean

rm vector.il
echo OK
