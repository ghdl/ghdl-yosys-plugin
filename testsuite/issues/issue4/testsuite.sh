#!/bin/sh

topdir=../..
. $topdir/testenv.sh

for f in no_vector counter8 vector; do
  synth "${f}.vhdl -e ${f}"
done

clean
echo OK
