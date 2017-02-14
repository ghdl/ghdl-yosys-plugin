#!/bin/sh

. ../testenv.sh

analyze ../../icezum/led_on/led_on.vhdl
synth led_on

analyze ../../icezum/blink/blink.vhdl
synth blink

analyze ../../icezum/pushbutton/pushbutton.vhdl
synth pushbutton

analyze ../../icezum/pushbutton_and/pushbutton_and.vhdl
synth pushbutton_and

clean
