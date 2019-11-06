#!/bin/sh

topdir=../..
. $topdir/testenv.sh

synth_import sync.vhdl -e
synth_import async.vhdl -e

clean
echo OK
