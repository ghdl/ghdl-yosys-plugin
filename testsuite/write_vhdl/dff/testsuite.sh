#!/bin/sh
# Test: write_vhdl DFF variants
# Verifies flip-flop output with VHDL-93 shadow signals
source "$(dirname "$0")/../../rename/common.sh"
check_tools

write_verilog dff.v << 'EOF'
module dff(input clk, input d, output reg q);
  always @(posedge clk) q <= d;
endmodule
EOF

(cd "$WORK" && yosys -m "$PLUGIN" \
    -p "read_verilog dff.v; proc; opt; write_vhdl -std 93 dff.vhd") \
    >"$WORK/yosys.log" 2>&1 || {
    echo "FAIL: write_vhdl failed"
    cat "$WORK/yosys.log" >&2
    exit 1
}

assert_has_vhdl dff.vhd "entity dff"
assert_has_vhdl dff.vhd "rising_edge"
assert_has_vhdl dff.vhd "end architecture"

if command -v "$GHDL" >/dev/null 2>&1; then
    (cd "$WORK" && "$GHDL" -a --std=08 dff.vhd) || {
        echo "FAIL: GHDL cannot parse DFF output"
        exit 1
    }
fi

echo "PASS: dff"