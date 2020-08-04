#!/bin/sh

topdir=../..
. $topdir/testenv.sh

synth_import --std=08 --work=aes_lib aes_pkg.vhdl cipher.vhdl -e

clean
echo OK
