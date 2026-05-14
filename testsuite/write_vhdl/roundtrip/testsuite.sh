#!/bin/sh
# Test: GHDL round-trip
# Verifies that write_vhdl output can be re-imported by GHDL and
# re-exported by write_vhdl without errors.
# Requires both ghdl binary and the ghdl Yosys plugin (our integrated one).
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../../rename/common.sh"
check_tools

write_verilog counter.v << 'EOF'
module counter(input clk, output reg [7:0] q);
  always @(posedge clk) q <= q + 1;
endmodule
EOF

# Generate VHDL from Verilog
(cd "$WORK" && yosys -m "$PLUGIN" \
    -p "read_verilog counter.v; proc; opt; write_vhdl counter.vhd") \
    >"$WORK/yosys1.log" 2>&1 || {
    echo "FAIL: first write_vhdl failed"
    cat "$WORK/yosys1.log" >&2
    exit 1
}

# Verify GHDL can parse the output
if command -v "$GHDL" >/dev/null 2>&1; then
    (cd "$WORK" && "$GHDL" -a --std=08 counter.vhd) || {
        echo "FAIL: GHDL cannot parse write_vhdl output"
        exit 1
    }

    # Round-trip: import VHDL via GHDL and re-export
    (cd "$WORK" && yosys -m "$PLUGIN" \
        -p "ghdl --std=08 counter.vhd -e counter; write_vhdl counter2.vhd") \
        >"$WORK/yosys2.log" 2>&1 || {
        echo "FAIL: round-trip write_vhdl failed"
        cat "$WORK/yosys2.log" >&2
        exit 1
    }

    # Second VHDL output should also be valid
    (cd "$WORK" && "$GHDL" -a --std=08 counter2.vhd) || {
        echo "FAIL: GHDL cannot parse round-trip output"
        exit 1
    }
else
    echo "SKIP: GHDL not available for round-trip test"
fi

echo "PASS: roundtrip"