#!/bin/sh

. ../testenv.sh

analyze ../../ice40hx8k/leds.vhdl
analyze ../../ice40hx8k/spin1.vhdl
synth leds

analyze ../../ice40hx8k/spin2.vhdl
synth leds

clean
