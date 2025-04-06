#!/bin/sh

topdir=../..
. $topdir/testenv.sh

synth_import top.vhdl -e

clean
echo OK
