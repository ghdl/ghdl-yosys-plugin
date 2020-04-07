#!/bin/sh

topdir=../..
. $topdir/testenv.sh

synth_import -fsynopsys counters_3.vhdl -e

clean
echo OK
