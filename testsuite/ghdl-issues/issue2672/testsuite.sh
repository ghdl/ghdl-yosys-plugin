#!/bin/sh

topdir=../..
. $topdir/testenv.sh

run_symbiyosys -fd work  repro.sby prove_1
#run_symbiyosys -fd work  prove_01-orig.sby prove_1

clean
echo OK
