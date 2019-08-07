#!/bin/sh

. ../testenv.sh

src=../../ice40hx8k

synth "$src/leds.vhdl $src/spin1.vhdl -e leds"
synth "$src/leds.vhdl $src/spin2.vhdl -e leds"

clean
