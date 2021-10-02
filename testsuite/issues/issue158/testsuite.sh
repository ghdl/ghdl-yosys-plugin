#!/bin/sh

topdir=../..
. $topdir/testenv.sh

for f in repro repro1 repro3 repro4; do
  synth "${f}.vhdl -e ${f}"
done

clean
echo OK
