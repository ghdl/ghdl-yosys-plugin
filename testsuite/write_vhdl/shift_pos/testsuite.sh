#!/bin/sh
# Test: write_vhdl shift and $pos operand type errors (#230, #231, #232)
#
# Three distinct bugs in operand wrapping, all with the same root cause:
# the shift handlers and $pos used dump_sigspec() directly on operands
# that require dump_sigspec_unsigned/signed to handle 1-bit signals and
# constants correctly.
#
# #230: shift by constant -- to_integer(unsigned("0000...1")) is illegal;
#       string literals cannot be type conversion operands in VHDL-93.
# #231: shift by 1-bit signal -- to_integer(unsigned(sig)) where sig is
#       std_logic; unsigned() requires std_logic_vector.
# #232: $pos extending a 1-bit signal -- resize(unsigned(data), N) where
#       data is std_logic; same type mismatch as #231.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../../rename/common.sh"
check_tools

run_test() {
    label="$1"
    src="$2"
    out="$3"

    cp "$SCRIPT_DIR/$src" "$WORK/$src"
    (cd "$WORK" && yosys -m "$PLUGIN" \
        -p "read_verilog $src; write_vhdl $out") \
        >"$WORK/${label}.log" 2>&1 || {
        echo "FAIL $label: yosys write_vhdl failed"
        cat "$WORK/${label}.log" >&2
        exit 1
    }

    if command -v "$GHDL" >/dev/null 2>&1; then
        "$GHDL" -s --std=93 "$WORK/$out" || {
            echo "FAIL $label: GHDL -s --std=93 rejected $out"
            exit 1
        }
        "$GHDL" -s --std=08 "$WORK/$out" || {
            echo "FAIL $label: GHDL -s --std=08 rejected $out"
            exit 1
        }
    fi

    echo "PASS: $label"
}

# ---------------------------------------------------------------------------
# t_shift_const: shift by constant -- issue #230
#   $shl, $shr, $sshl, $sshr with B a 32-bit RTLIL constant
# ---------------------------------------------------------------------------
run_test t_shift_const t_shift_const.v t_shift_const.vhd

# ---------------------------------------------------------------------------
# t_shift_1bit: shift with 1-bit operands -- issues #231 and related
#   $shl, $shr with B_WIDTH=1 (std_logic shift amount, issue #231)
#   $shl, $shr with A_WIDTH=1 (std_logic value being shifted)
# ---------------------------------------------------------------------------
run_test t_shift_1bit t_shift_1bit.v t_shift_1bit.vhd

# ---------------------------------------------------------------------------
# t_pos_1bit: $pos extending 1-bit signal to wider type -- issue #232
#   $pos A_WIDTH=1, Y_WIDTH=4 triggered by ternary with mixed widths
# ---------------------------------------------------------------------------
run_test t_pos_1bit t_pos_1bit.v t_pos_1bit.vhd

echo "PASS: shift_pos"
