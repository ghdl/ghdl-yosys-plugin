#!/bin/sh
# Test: write_vhdl $shift with B_SIGNED=1 (bidirectional shift)
#
# When B_SIGNED=1 and B < 0, $shift means left-shift by |B|.
# The old code always emitted shift_right(A, to_integer(signed(B))), which
# is undefined behaviour in VHDL for negative B.
#
# The fix emits a conditional:
#   shift_left(A, abs(signed(B))) when B(MSB) = '1' else shift_right(A, B)
#
# The RTLIL is injected directly because the Verilog frontend normalises
# bidirectional signed shifts to $shl/$shr/$sshr before we see them.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../../rename/common.sh"
check_tools

# Inject RTLIL with $shift B_SIGNED=1
cat > "$WORK/shift_signed.il" << 'EOIL'
autoidx 1
module \shift_signed
  wire width 8 output 1 \y
  wire width 8 input 2 \a
  wire width 4 input 3 \b
  cell $shift $1
    parameter \A_SIGNED 0
    parameter \A_WIDTH 8
    parameter \B_SIGNED 1
    parameter \B_WIDTH 4
    parameter \Y_WIDTH 8
    connect \A \a
    connect \B \b
    connect \Y \y
  end
end
EOIL

(cd "$WORK" && yosys -m "$PLUGIN" \
    -p "read_rtlil shift_signed.il; write_vhdl shift_signed.vhd") \
    >"$WORK/yosys.log" 2>&1 || {
    echo "FAIL: write_vhdl failed"
    cat "$WORK/yosys.log" >&2
    exit 1
}

assert_has_vhdl shift_signed.vhd "entity shift_signed"

# Must contain the conditional form: shift_left ... when ... else shift_right
if ! grep -q "shift_left" "$WORK/shift_signed.vhd"; then
    echo "FAIL: expected 'shift_left' in generated VHDL (B_SIGNED=1 path missing)"
    cat "$WORK/shift_signed.vhd" >&2
    exit 1
fi
if ! grep -q "when" "$WORK/shift_signed.vhd"; then
    echo "FAIL: expected 'when' conditional in generated VHDL"
    cat "$WORK/shift_signed.vhd" >&2
    exit 1
fi

if ! command -v "$GHDL" >/dev/null 2>&1; then
    echo "PASS: shift_signed (parse only, GHDL unavailable)"
    exit 0
fi

(cd "$WORK" && "$GHDL" -a --std=08 shift_signed.vhd) || {
    echo "FAIL: GHDL cannot parse output"
    exit 1
}

# Simulate: write a testbench that checks both shift directions
cat > "$WORK/tb.vhd" << 'EOVHD'
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb is end entity tb;

architecture sim of tb is
    signal a : std_logic_vector(7 downto 0);
    signal b : std_logic_vector(3 downto 0);
    signal y : std_logic_vector(7 downto 0);
begin
    dut : entity work.shift_signed port map(y => y, a => a, b => b);

    process
    begin
        -- Positive B=2: shift right by 2. 0x08 >> 2 = 0x02
        a <= x"08"; b <= "0010"; wait for 10 ns;
        assert y = x"02"
            report "FAIL: shift_right(0x08, 2) expected 0x02, got " & to_hstring(y)
            severity failure;

        -- Negative B=-2 (two's complement 4-bit: "1110"): shift left by 2. 0x02 << 2 = 0x08
        a <= x"02"; b <= "1110"; wait for 10 ns;
        assert y = x"08"
            report "FAIL: shift_left(0x02, 2) expected 0x08, got " & to_hstring(y)
            severity failure;

        -- B=0: no shift. 0xAB >> 0 = 0xAB
        a <= x"AB"; b <= "0000"; wait for 10 ns;
        assert y = x"AB"
            report "FAIL: shift(0xAB, 0) expected 0xAB, got " & to_hstring(y)
            severity failure;

        -- Negative B=-1 ("1111"): shift left by 1. 0x01 << 1 = 0x02
        a <= x"01"; b <= "1111"; wait for 10 ns;
        assert y = x"02"
            report "FAIL: shift_left(0x01, 1) expected 0x02, got " & to_hstring(y)
            severity failure;

        report "PASS" severity note;
        wait;
    end process;
end architecture sim;
EOVHD

(cd "$WORK" && "$GHDL" -a --std=08 tb.vhd && \
    "$GHDL" -e --std=08 tb && \
    "$GHDL" -r --std=08 tb --assert-level=failure) || {
    echo "FAIL: simulation failed"
    exit 1
}

echo "PASS: shift_signed"
