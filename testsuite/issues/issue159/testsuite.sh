#!/bin/sh

topdir=../..
. $topdir/testenv.sh

for f in repro repro2; do
  synth_import "${f}.vhdl -e ${f}"
done

clean
echo OK
