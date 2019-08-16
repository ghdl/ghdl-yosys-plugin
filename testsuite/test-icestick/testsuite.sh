#!/bin/sh

. ../testenv.sh

src=../../icestick

# spin2

for f in fixed1 blink multi1 multi2 spin1 rotate1 rotate2 rotate3 rotate4; do
 synth "$src/leds.vhdl $src/${f}.vhdl -e leds"
done

clean
