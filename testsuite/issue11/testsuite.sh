#!/bin/sh

. ../testenv.sh

analyze test_or.vhdl
synth test_or

analyze test_xor.vhdl
synth test_xor

analyze test_nor.vhdl
synth test_nor

analyze test_nand.vhdl
synth test_nand

analyze test_xnor.vhdl
synth test_xnor

clean
