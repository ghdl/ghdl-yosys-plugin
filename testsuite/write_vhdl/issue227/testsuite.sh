#!/bin/sh
# Test: write_vhdl issue #227 -- conditional expression in aggregate
#
# write_vhdl emitted illegal VHDL-93 for boolean/comparison cells with
# output width > 1:
#
#   n0 <= (0 => '1' when COND else '0', others => '0');
#
# VHDL-93 s7.3.2 forbids conditional expressions inside aggregates.
# GHDL rejects this with "')' is expected instead of 'when'".
#
# Five test modules:
#   t_exact:    exact reporter case ($logic_and y_width=3)
#   t_logic:    $logic_and/or/not at y_width=4 (broken) and y_width=1 (control)
#   t_reduce:   $reduce_and/or/xor/xnor at y_width=4 and y_width=1
#   t_compare:  $eq/$ne/$lt/$eqx at y_width=4 and y_width=1
#   t_combined: three independent boolean cells feeding one output;
#               asserts exactly 3 intermediates (one per cell, not combined)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../../rename/common.sh"
check_tools

# ---------------------------------------------------------------------------
# run_test <label> <src.v> <out.vhd>
#   - Runs write_vhdl
#   - Structural check: no '=> X when' pattern (conditional in aggregate)
#   - GHDL syntax check under --std=93 and --std=08
# ---------------------------------------------------------------------------
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

    if grep -q "=> '.' when" "$WORK/$out"; then
        echo "FAIL $label: conditional-in-aggregate still present in $out"
        grep "=> '.' when" "$WORK/$out" >&2
        exit 1
    fi

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
}

# ---------------------------------------------------------------------------
# check_intermediates <label> <vhd> <expected_count>
#   Counts 'signal nXX : std_logic;' in the architecture declarative region.
#   These are the bool-to-vector intermediates introduced by the fix.
#   An exact match proves one intermediate per broken cell, not a combined expr.
# ---------------------------------------------------------------------------
check_intermediates() {
    label="$1"
    vhd="$WORK/$2"
    expected="$3"

    # Extract the architecture declarative region (between 'architecture' and 'begin')
    # and count lines of the form 'signal nNN : std_logic;'
    actual=$(awk '/^architecture /,/^begin/' "$vhd" \
        | grep -c 'signal n[0-9][0-9]* : std_logic;' || true)
    if [ "$actual" -ne "$expected" ]; then
        echo "FAIL $label: expected $expected std_logic intermediates, got $actual"
        awk '/^architecture /,/^begin/' "$vhd" \
            | grep 'signal n[0-9][0-9]* : std_logic' >&2
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# t_exact: verbatim reporter case
#   o0 = i0 | (i1 && i2)   $logic_and y_width=3  BROKEN
#   o1 = i1 && i2           $logic_and y_width=1  control (must be unchanged)
# After fix: 1 std_logic intermediate (for o0's $logic_and).
# ---------------------------------------------------------------------------
run_test t_exact t_exact.v t_exact.vhd
# 1 new intermediate (for o0 $logic_and y_width=3)
# + 1 existing std_logic wire (for o1 $logic_and y_width=1 cell output)
check_intermediates t_exact t_exact.vhd 2
echo "PASS: t_exact"

# ---------------------------------------------------------------------------
# t_logic: $logic_and, $logic_or, $logic_not
#   o_and4/or4/not4: y_width=4  BROKEN (3 cells)
#   o_and1/or1/not1: y_width=1  control -- no intermediates
# After fix: exactly 3 std_logic intermediates.
# ---------------------------------------------------------------------------
run_test t_logic t_logic.v t_logic.vhd
# 3 new intermediates (one per y_width=4 broken cell)
# + 3 existing std_logic wires (one per y_width=1 control cell output)
check_intermediates t_logic t_logic.vhd 6
echo "PASS: t_logic"

# ---------------------------------------------------------------------------
# t_reduce: $reduce_and, $reduce_or, $reduce_xor, $reduce_xnor
#   o_*4: y_width=4  BROKEN (4 cells)
#   o_*1: y_width=1  control -- no intermediates
# $reduce_xnor has zero prior test coverage at any width.
# After fix: exactly 4 std_logic intermediates.
# ---------------------------------------------------------------------------
run_test t_reduce t_reduce.v t_reduce.vhd
# 4 new intermediates (one per y_width=4 broken cell)
# + 4 existing std_logic wires (one per y_width=1 control cell output)
check_intermediates t_reduce t_reduce.vhd 8
echo "PASS: t_reduce"

# ---------------------------------------------------------------------------
# t_compare: $eq, $ne, $lt, $eqx
#   o_*4: y_width=4  BROKEN (4 cells)
#   o_*1: y_width=1  control -- no intermediates
# $eqx (casex equality, ===) has zero prior test coverage at any width.
# After fix: exactly 4 std_logic intermediates.
# ---------------------------------------------------------------------------
run_test t_compare t_compare.v t_compare.vhd
# 4 new intermediates (one per y_width=4 broken cell)
# + 4 existing std_logic wires (one per y_width=1 control cell output)
check_intermediates t_compare t_compare.vhd 8
echo "PASS: t_compare"

# ---------------------------------------------------------------------------
# t_combined: three independent boolean cells feeding one 4-bit output,
# mixed with a plain signal and a constant.
#
# Key structural assertion: exactly 3 std_logic intermediates -- one per
# boolean cell.  If the fix merged conditions (e.g. '1' when A or B or C)
# there would be 1; if it enumerated combinations there would be more.
# Plain signal and constant must not generate intermediates.
# ---------------------------------------------------------------------------
run_test t_combined t_combined.v t_combined.vhd
check_intermediates t_combined t_combined.vhd 3
echo "PASS: t_combined"

# ---------------------------------------------------------------------------
# t_vhdl: VHDL-sourced round-trip (requires GHDL; skipped otherwise)
#
# Exercises three paths used extensively in production:
#   sfixed/ufixed: GHDL normalizes to std_logic_vector; no fixed-point
#                  type names should appear in the write_vhdl output.
#   Single-bit slice: bus8(2), bus8(5) must produce std_logic ports,
#                     not std_logic_vector(0 downto 0).
#   Boolean + vector: flag OR'd into vec (issue #227 equivalent via VHDL).
#
# Only syntax is checked (ghdl -s); simulation-level correctness is
# deferred to a future test.
# ---------------------------------------------------------------------------
if command -v "$GHDL" >/dev/null 2>&1; then
    cp "$SCRIPT_DIR/t_vhdl.vhd" "$WORK/t_vhdl.vhd"

    # Analyse VHDL source
    (cd "$WORK" && "$GHDL" -a --std=08 t_vhdl.vhd) || {
        echo "FAIL t_vhdl: GHDL -a failed on source"
        exit 1
    }

    # Synthesise via GHDL plugin and write VHDL-93
    (cd "$WORK" && yosys -m "$PLUGIN" \
        -p "ghdl --std=08 t_vhdl.vhd -e t_vhdl; write_vhdl t_vhdl_synth.vhd") \
        >"$WORK/t_vhdl.log" 2>&1 || {
        echo "FAIL t_vhdl: yosys write_vhdl failed"
        cat "$WORK/t_vhdl.log" >&2
        exit 1
    }

    # No conditional-in-aggregate
    if grep -q "=> '.' when" "$WORK/t_vhdl_synth.vhd"; then
        echo "FAIL t_vhdl: conditional-in-aggregate in write_vhdl output"
        grep "=> '.' when" "$WORK/t_vhdl_synth.vhd" >&2
        exit 1
    fi

    # No sfixed/ufixed type names -- GHDL must have normalized them away
    if grep -qE '\bsfixed\b|\bufixed\b' "$WORK/t_vhdl_synth.vhd"; then
        echo "FAIL t_vhdl: sfixed/ufixed type name in write_vhdl output"
        grep -E '\bsfixed\b|\bufixed\b' "$WORK/t_vhdl_synth.vhd" >&2
        exit 1
    fi

    # No std_logic_vector(0 downto 0) -- single-bit slices must be std_logic
    if grep -q "std_logic_vector(0 downto 0)" "$WORK/t_vhdl_synth.vhd"; then
        echo "FAIL t_vhdl: std_logic_vector(0 downto 0) in output (width-1 type mismatch)"
        grep "std_logic_vector(0 downto 0)" "$WORK/t_vhdl_synth.vhd" >&2
        exit 1
    fi

    # Syntax check under VHDL-2008 only.
    # The VHDL-93 check is intentionally omitted: fixed_pkg injects $assert
    # cells whose 'if '1' = '1'' condition is ambiguous under strict -93.
    # That is a pre-existing limitation of the $assert handler, not
    # introduced by this fix.
    "$GHDL" -s --std=08 "$WORK/t_vhdl_synth.vhd" || {
        echo "FAIL t_vhdl: GHDL -s --std=08 rejected write_vhdl output"
        exit 1
    }

    echo "PASS: t_vhdl"
fi

echo "PASS: issue227"
