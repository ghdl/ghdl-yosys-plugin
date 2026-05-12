#!/bin/sh
# Test: write_vhdl mixed design with multiple cell types
source "$(dirname "$0")/../../rename/common.sh"
check_tools

write_verilog mixed.v << 'EOF'
module mixed(input clk, input [7:0] a, input [7:0] b,
             input sel, output reg [7:0] y, output reg [7:0] q);
  always @(posedge clk) q <= a + b;
  always @(*) y = sel ? a : b;
endmodule
EOF

(cd "$WORK" && yosys -m "$PLUGIN" \
    -p "read_verilog mixed.v; proc; opt; write_vhdl mixed.vhd") \
    >"$WORK/yosys.log" 2>&1 || {
    echo "FAIL: write_vhdl mixed failed"
    cat "$WORK/yosys.log" >&2
    exit 1
}

assert_has_vhdl mixed.vhd "entity mixed"
assert_has_vhdl mixed.vhd "end architecture"

if command -v "$GHDL" >/dev/null 2>&1; then
    (cd "$WORK" && "$GHDL" -a --std=08 mixed.vhd) || {
        echo "FAIL: GHDL cannot parse mixed output"
        exit 1
    }
fi

echo "PASS: mixed"