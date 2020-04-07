#!/bin/sh

topdir=../..
. $topdir/testenv.sh

synth_import -fsynopsys counters_8.vhdl -e

clean
echo OK
