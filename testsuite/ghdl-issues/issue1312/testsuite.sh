#!/bin/sh

topdir=../..
. $topdir/testenv.sh

synth_import --std=08 ent.vhdl -e

clean
echo OK
