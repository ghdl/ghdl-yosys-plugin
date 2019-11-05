#!/bin/sh

# Same as testsuite.sh but should really fail.
topdir=../..
. $topdir/testenv.sh

synth_import --std=08 test.vhdl -e

clean
echo OK
