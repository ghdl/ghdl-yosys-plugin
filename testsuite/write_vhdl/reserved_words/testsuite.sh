#!/bin/sh
# Test: write_vhdl reserved word escaping
# Verifies that VHDL reserved words used as signal names are escaped
source "$(dirname "$0")/../../rename/common.sh"
check_tools

write_verilog reserved.v << 'EOF'
module reserved(input clk, input signal, input map, output reg q);
  always @(posedge clk) q <= signal & map;
endmodule
EOF

(cd "$WORK" && yosys -m "$PLUGIN" \
    -p "read_verilog reserved.v; proc; opt; write_vhdl reserved.vhd") \
    >"$WORK/yosys.log" 2>&1 || {
    echo "FAIL: write_vhdl reserved words failed"
    cat "$WORK/yosys.log" >&2
    exit 1
}

# "signal" and "map" are VHDL reserved words and must be escaped
assert_has_vhdl reserved.vhd "\\signal\\"
assert_has_vhdl reserved.vhd "\\map\\"

echo "PASS: reserved_words"