#!/bin/sh

. ../testenv.sh

analyze novector.vhdl
synth no_vector

analyze counter8.vhdl
synth counter8

analyze vector.vhdl
synth vector

clean
