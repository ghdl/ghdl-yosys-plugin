#!/bin/sh

topdir=../..
. $topdir/testenv.sh

synth "demux.vhdl -e"

clean
