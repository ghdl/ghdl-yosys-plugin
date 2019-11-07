#!/bin/sh

topdir=../..
. $topdir/testenv.sh

synth_import --std=08 latch3.vhdl -e

clean
echo OK
