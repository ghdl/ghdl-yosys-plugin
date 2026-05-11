#!/bin/sh

topdir=../..
. $topdir/testenv.sh

for f in test1 test2; do
    run_yosys -q -p "ghdl ${f}.vhdl -e; write_rtlil ${f}.il"
    fgrep -q 'connect \b_io \a_i' ${f}.il
    fgrep -q 'connect \c_io \a_i' ${f}.il
done

echo OK
