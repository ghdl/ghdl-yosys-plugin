#!/bin/sh

topdir=../..
. $topdir/testenv.sh

synth_import bram.vhdl -e

clean
echo OK
