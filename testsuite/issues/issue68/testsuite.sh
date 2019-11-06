#!/bin/sh

topdir=../..
. $topdir/testenv.sh

synth_ice40 "demux.vhdl -e"

clean
