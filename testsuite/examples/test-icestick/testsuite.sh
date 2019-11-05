#!/bin/sh

topdir=../..
. $topdir/testenv.sh

src=../../../icestick

# spin2

for f in fixed1 blink multi1 multi2 spin1 rotate1 rotate2 rotate3 rotate4; do
 synth_ice40 $src/leds.vhdl $src/${f}.vhdl -e leds
done

UART_SRC=$src/uart/hdl
synth_ice40 $UART_SRC/uart_rx.vhd $UART_SRC/uart_tx.vhd $UART_SRC/uart_top.vhd -e uart_top

clean
