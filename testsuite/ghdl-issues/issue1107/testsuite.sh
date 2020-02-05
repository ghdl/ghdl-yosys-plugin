#!/bin/sh

topdir=../..
. $topdir/testenv.sh

synth_import unconnected.vhdl -e

clean
echo OK
