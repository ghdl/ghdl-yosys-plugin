#!/bin/sh

topdir=../..
. $topdir/testenv.sh

for f in fpu fpu2; do
  synth_import "--std=08 ${f}.vhdl -e"
done

echo OK
