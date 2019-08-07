#!/bin/sh

. ../testenv.sh

src=../../icezum

synth "$src/led_on/led_on.vhdl -e led_on"
synth "$src/blink/blink.vhdl -e blink"
synth "$src/pushbutton/pushbutton.vhdl -e pushbutton"
synth "$src/pushbutton_and/pushbutton_and.vhdl -e pushbutton_and"

clean
