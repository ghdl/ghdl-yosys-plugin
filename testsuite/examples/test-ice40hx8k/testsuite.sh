#!/bin/sh

topdir=../..
. $topdir/testenv.sh

src=../../../examples/ice40hx8k

synth_ice40 $src/leds.vhdl $src/spin1.vhdl -e leds
synth_ice40 $src/leds.vhdl $src/spin2.vhdl -e leds

clean
