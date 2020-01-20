#!/bin/sh

topdir=../..
. $topdir/testenv.sh

synth 'vector.vhdl -e vector'

clean
echo OK
