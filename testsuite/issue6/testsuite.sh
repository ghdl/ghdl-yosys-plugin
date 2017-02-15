#!/bin/sh

. ../testenv.sh

analyze vector.vhdl
synth vector

clean
