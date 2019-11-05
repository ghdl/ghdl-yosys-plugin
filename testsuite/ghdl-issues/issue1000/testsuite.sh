#!/bin/sh

topdir=../..
. $topdir/testenv.sh

synth_import --std=08 test.vhdl -e

clean
