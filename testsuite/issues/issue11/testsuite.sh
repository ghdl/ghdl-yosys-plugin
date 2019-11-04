#!/bin/sh

topdir=../..
. $topdir/testenv.sh

for f in or xor nor nand xnor; do
  synth "test_${f}.vhdl -e test_${f}"
done

clean
