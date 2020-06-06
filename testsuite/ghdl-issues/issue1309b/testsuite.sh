#!/bin/sh

topdir=../..
. $topdir/testenv.sh

run_symbiyosys -fd work/psl_test psl_test.sby prove

clean
echo OK
