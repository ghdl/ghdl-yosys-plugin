#!/bin/sh
# Test: write_vhdl J-Core CPU synthesis
#
# Synthesises the J-Core SH2-compatible CPU from VHDL source via the GHDL
# plugin and verifies that write_vhdl produces VHDL-93 that GHDL accepts.
#
# This is a real-world integration test: the J-Core CPU is a substantial
# VHDL design (~14 source files, ~15k lines of synthesised VHDL output)
# that exercises record ports, nested entities, FFs, memories, and the
# full range of cell types the backend must handle.
#
# Source: testsuite/write_vhdl/jcore/jcore-src/   (not checked in)
#
# To run this test, populate jcore-src/ with the J-Core RTL source tree.
# The expected layout mirrors jcore-calc-ghdl/:
#   jcore-src/
#     tools/v2p          perl macro preprocessor
#     cpu2j0_pkg.vhd     and the remaining RTL .vhd/.vhm files
#
# The .vhm files are VHDL with macro-preprocessing; the test runs
# perl tools/v2p to expand them to plain VHDL before analysis.
#
# Skipped if jcore-src/ is not present.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../../rename/common.sh"
check_tools

JCORE="$SCRIPT_DIR/jcore-src"

if [ ! -d "$JCORE" ]; then
    echo "SKIP: J-Core source not found (populate $SCRIPT_DIR/jcore-src/)"
    exit 0
fi

if [ ! -f "$JCORE/tools/v2p" ]; then
    echo "SKIP: J-Core preprocessor not found at $JCORE/tools/v2p"
    exit 0
fi

# Preprocess .vhm -> .vhd
for vhm in "$JCORE"/*.vhm; do
    base=$(basename "${vhm%.vhm}")
    perl "$JCORE/tools/v2p" < "$vhm" > "$WORK/${base}.vhd"
done

# Copy plain .vhd RTL files
cp "$JCORE"/cpu2j0_pkg.vhd \
   "$JCORE"/components_pkg.vhd \
   "$JCORE"/mult_pkg.vhd \
   "$JCORE"/decode_pkg.vhd \
   "$JCORE"/decode_body.vhd \
   "$JCORE"/datapath_pkg.vhd \
   "$JCORE"/cpu.vhd \
   "$JCORE"/decode.vhd \
   "$JCORE"/decode_table.vhd \
   "$JCORE"/register_file_sync.vhd \
   "$JCORE"/decode_table_reverse.vhd \
   "$WORK/" 2>/dev/null || {
    echo "FAIL jcore: could not copy RTL source files"
    exit 1
}

# Analyse in dependency order (--std=08 for VHDL-2008 compatibility)
CORE_FILES="cpu2j0_pkg.vhd components_pkg.vhd mult_pkg.vhd decode_pkg.vhd \
decode_body.vhd datapath_pkg.vhd cpu.vhd decode.vhd decode_core.vhd \
decode_table.vhd datapath.vhd register_file_sync.vhd mult.vhd decode_table_reverse.vhd"

(cd "$WORK" && for f in $CORE_FILES; do
    "$GHDL" -a --std=08 "$f" 2>/dev/null || {
        echo "FAIL jcore: ghdl -a failed on $f"
        exit 1
    }
done) || exit 1

# Synthesise the top-level cpu entity and emit VHDL-93
(cd "$WORK" && yosys -m "$PLUGIN" \
    -p "ghdl --std=08 $CORE_FILES -e cpu; write_vhdl cpu_synth.vhd") \
    >"$WORK/yosys.log" 2>&1 || {
    echo "FAIL jcore: yosys synthesis failed"
    cat "$WORK/yosys.log" >&2
    exit 1
}

if [ ! -f "$WORK/cpu_synth.vhd" ]; then
    echo "FAIL jcore: write_vhdl produced no output"
    exit 1
fi

lines=$(wc -l < "$WORK/cpu_synth.vhd")
echo "  cpu_synth.vhd: $lines lines"

# Syntax check the output under both VHDL standards
"$GHDL" -s --std=93 "$WORK/cpu_synth.vhd" || {
    echo "FAIL jcore: GHDL -s --std=93 rejected cpu_synth.vhd"
    exit 1
}
"$GHDL" -s --std=08 "$WORK/cpu_synth.vhd" || {
    echo "FAIL jcore: GHDL -s --std=08 rejected cpu_synth.vhd"
    exit 1
}

echo "PASS: jcore"
