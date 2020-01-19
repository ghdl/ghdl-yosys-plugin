#!/bin/sh

topdir=../..
. $topdir/testenv.sh

src=../../../examples/icezum

synth_ice40 $src/led_on.vhdl -e led_on
synth_ice40 $src/blink.vhdl -e blink
synth_ice40 $src/pushbutton.vhdl -e pushbutton
synth_ice40 $src/counter.vhdl -e counter

clean
