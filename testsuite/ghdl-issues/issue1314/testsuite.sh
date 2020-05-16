#!/bin/sh

topdir=../..
. $topdir/testenv.sh

synth_import --std=08 issue.vhdl -e

clean
echo OK
