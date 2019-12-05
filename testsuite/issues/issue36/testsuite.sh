#!/bin/sh

topdir=../..
. $topdir/testenv.sh

synth_import bram.vhdl -e
synth_import bram2.vhdl -e
synth_import bram3.vhdl -e

clean
echo OK
