#!/bin/sh

topdir=../..
. $topdir/testenv.sh

src=../../../icezum

synth_ice40 $src/led_on/led_on.vhdl -e led_on
synth_ice40 $src/blink/blink.vhdl -e blink
synth_ice40 $src/pushbutton/pushbutton.vhdl -e pushbutton
synth_ice40 $src/pushbutton_and/pushbutton_and.vhdl -e pushbutton_and

clean
