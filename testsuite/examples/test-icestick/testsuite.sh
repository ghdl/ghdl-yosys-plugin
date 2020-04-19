#!/bin/sh

topdir=../..
. $topdir/testenv.sh

src=../../../examples/icestick

# spin2

LEDS_SRC=$src/leds
for f in fixed1 blink multi1 multi2 spin1 rotate1 rotate2 rotate3 rotate4; do
 synth_ice40 $LEDS_SRC/leds.vhdl $LEDS_SRC/${f}.vhdl -e leds
done

UART_SRC=$src/uart/hdl
synth_ice40 $UART_SRC/uart_rx.vhd $UART_SRC/uart_tx.vhd $UART_SRC/uart_top.vhd -e uart_top

clean
