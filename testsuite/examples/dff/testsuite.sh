#!/bin/sh

topdir=../..
. $topdir/testenv.sh

run_yosys -q -p "ghdl negdff.vhdl -e; write_rtlil negdff.ilang"
fgrep -q "cell \$dff" negdff.ilang
fgrep -q "CLK_POLARITY 0" negdff.ilang
fgrep -q "WIDTH 1" negdff.ilang

run_yosys -q -p "ghdl dff.vhdl -e; write_rtlil dff.ilang"
fgrep -q "CLK_POLARITY 1" dff.ilang
fgrep -q "WIDTH 1" dff.ilang

run_yosys -q -p "ghdl adff.vhdl -e; opt; write_rtlil adff.ilang"
fgrep -q 'cell $adff' adff.ilang
fgrep -q 'ARST_POLARITY 1' adff.ilang
fgrep -q "ARST_VALUE 1'1" adff.ilang
fgrep -q 'CLK_POLARITY 1' adff.ilang
fgrep -q 'WIDTH 1' adff.ilang

run_yosys -q -p "ghdl negadff.vhdl -e; write_rtlil negadff.ilang"
fgrep -q 'cell $adff' negadff.ilang
fgrep -q 'ARST_POLARITY 1' negadff.ilang
fgrep -q "ARST_VALUE 1'0" negadff.ilang
fgrep -q 'CLK_POLARITY 0' negadff.ilang
fgrep -q 'WIDTH 1' negadff.ilang

clean
echo OK
