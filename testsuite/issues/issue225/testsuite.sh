#!/bin/sh

topdir=../..
. $topdir/testenv.sh

for f in test1 test2; do
    run_yosys -q -p "ghdl ${f}.vhdl -e; \
        select -module ${f}; \
        select -assert-count 1 i:c_io; \
        select -assert-count 1 o:c_io; \
        write_rtlil ${f}.il"
    fgrep -q 'connect \b_io \a_i' ${f}.il
    fgrep -q 'connect \c_io \a_i' ${f}.il
done

rm -f test1.il test2.il

echo OK
