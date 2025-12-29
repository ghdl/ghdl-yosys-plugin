#!/bin/sh

topdir=../..
. $topdir/testenv.sh

run_yosys -q -s cmd.ys -l cmd.log

fgrep 'Equivalence successfully proven' cmd.log

echo OK
