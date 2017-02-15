#!/bin/sh

. ../testenv.sh

src=../../icestick

analyze $src/leds.vhdl

files="fixed1.vhdl
 fixed1.vhdl
 blink.vhdl
 multi1.vhdl
 multi2.vhdl
 spin1.vhdl
 rotate1.vhdl
 rotate2.vhdl
 rotate3.vhdl
 rotate4.vhdl
"
# spin2.vhdl

for f in $files; do
 analyze $src/$f
 synth leds
done

clean
