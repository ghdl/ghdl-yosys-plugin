#!/bin/sh

topdir=../..
. $topdir/testenv.sh

if synth_import --std=08 test.vhdl -e; then
  echo "test is expected to fail"
  exit 1
fi

clean
echo OK
