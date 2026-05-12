#!/bin/sh
# Test: write_vhdl basic entity generation
# Verifies that write_vhdl produces valid VHDL from a simple Verilog design

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../../rename/common.sh"
check_tools

write_verilog counter.v << 'EOF'
module counter(input clk, output reg [7:0] q);
  always @(posedge clk)
    q <= q + 1;
endmodule
EOF

(cd "$WORK" && yosys -m "$PLUGIN" \
    -p "read_verilog counter.v; proc; opt; write_vhdl counter.vhd") \
    >"$WORK/yosys.log" 2>&1 || {
    echo "FAIL: write_vhdl failed"
    cat "$WORK/yosys.log" >&2
    exit 1
}

# Verify VHDL output has expected structure
assert_has_vhdl counter.vhd "entity counter"
assert_has_vhdl counter.vhd "port"
assert_has_vhdl counter.vhd "clk"
assert_has_vhdl counter.vhd "end entity"

# Verify GHDL can parse it (if available)
if command -v "$GHDL" >/dev/null 2>&1; then
    (cd "$WORK" && "$GHDL" -a --std=08 counter.vhd) || {
        echo "FAIL: GHDL cannot parse write_vhdl output"
        exit 1
    }
fi

echo "PASS: basic"