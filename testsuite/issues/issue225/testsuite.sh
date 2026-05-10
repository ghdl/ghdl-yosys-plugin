#!/bin/sh

topdir=../..
. $topdir/testenv.sh

synth "test1.vhdl -e test1"

echo OK
