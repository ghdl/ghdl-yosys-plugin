#!/bin/sh
# Test: write_vhdl hierarchical design
# Verifies component declarations and port maps

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../../rename/common.sh"
check_tools

write_verilog top.v << 'EOF'
module sub(input clk, input [7:0] d, output [7:0] q);
  always @(posedge clk) q <= d;
endmodule

module top(input clk, input [7:0] d, output [7:0] q);
  sub u_sub(.clk(clk), .d(d), .q(q));
endmodule
EOF

(cd "$WORK" && yosys -m "$PLUGIN" \
    -p "read_verilog top.v; proc; opt; write_vhdl top.vhd") \
    >"$WORK/yosys.log" 2>&1 || {
    echo "FAIL: write_vhdl hierarchy failed"
    cat "$WORK/yosys.log" >&2
    exit 1
}

assert_has_vhdl top.vhd "entity sub"
assert_has_vhdl top.vhd "entity top"
assert_has_vhdl top.vhd "component sub"

if command -v "$GHDL" >/dev/null 2>&1; then
    (cd "$WORK" && "$GHDL" -a --std=08 top.vhd) || {
        echo "FAIL: GHDL cannot parse hierarchical VHDL output"
        exit 1
    }
fi

echo "PASS: hierarchy"