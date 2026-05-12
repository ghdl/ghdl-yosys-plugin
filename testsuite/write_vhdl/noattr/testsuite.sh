#!/bin/sh
# Test: write_vhdl -noattr option
# Verifies that -noattr suppresses attribute comments
source "$(dirname "$0")/../../rename/common.sh"
check_tools

write_verilog test.v << 'EOF'
module test(input clk, input d, output reg q);
  always @(posedge clk) q <= d;
endmodule
EOF

(cd "$WORK" && yosys -m "$PLUGIN" \
    -p "read_verilog test.v; proc; opt; write_vhdl -noattr test.vhd") \
    >"$WORK/yosys.log" 2>&1 || {
    echo "FAIL: write_vhdl -noattr failed"
    cat "$WORK/yosys.log" >&2
    exit 1
}

# With -noattr, there should be no "attribute" keyword in the output
if grep -q "^  attribute " "$WORK/test.vhd"; then
    echo "FAIL: -noattr did not suppress attributes"
    cat "$WORK/test.vhd"
    exit 1
fi

echo "PASS: noattr"