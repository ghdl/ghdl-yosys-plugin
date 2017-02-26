#!/bin/sh

. ../testenv.sh

analyze test_or.vhdl
synth test_or

analyze test_xor.vhdl
synth test_xor

clean
