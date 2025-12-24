#!/bin/sh

topdir=../..
. $topdir/testenv.sh

#run_yosys -p 'ghdl sub.vhdl top.v -e; hierarchy'

if run_yosys -l log.txt -p 'ghdl -read sub.vhdl; read_verilog top.v; hierarchy -top top'
then
    echo "error expected"
    exit 1
fi

grep -q "ERROR: Incorrect use of module" log.txt


echo OK
