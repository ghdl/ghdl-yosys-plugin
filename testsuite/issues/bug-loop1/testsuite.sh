#!/bin/sh

topdir=../..
. $topdir/testenv.sh

for f in loop1; do
  synth "${f}.vhdl -e ${f}"
done

clean
echo OK
