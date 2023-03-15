#!/bin/sh

topdir=../..
. $topdir/testenv.sh

run_yosys psl_p_plus.ys

run_symbiyosys -f compare_psl_p_plus.sby compare cover

echo OK
