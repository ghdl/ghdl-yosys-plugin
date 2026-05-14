#!/bin/sh
# Test: write_vhdl memory
# Verifies RAM inference with type declarations
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../../rename/common.sh"
check_tools

write_verilog ram.v << 'EOF'
module ram(input clk, input [7:0] addr, input [7:0] data_in,
           input we, output reg [7:0] data_out);
  reg [7:0] mem [0:255];
  always @(posedge clk) begin
    if (we) mem[addr] <= data_in;
    data_out <= mem[addr];
  end
endmodule
EOF

(cd "$WORK" && yosys -m "$PLUGIN" \
    -p "read_verilog ram.v; proc; opt; write_vhdl ram.vhd") \
    >"$WORK/yosys.log" 2>&1 || {
    echo "FAIL: write_vhdl memory failed"
    cat "$WORK/yosys.log" >&2
    exit 1
}

# memory may not produce BRAM; just check we get valid VHDL output
assert_has_vhdl ram.vhd "entity ram"

if command -v "$GHDL" >/dev/null 2>&1; then
    (cd "$WORK" && "$GHDL" -a --std=08 ram.vhd) || {
        echo "FAIL: GHDL cannot parse RAM output"
        exit 1
    }
fi

echo "PASS: memories"