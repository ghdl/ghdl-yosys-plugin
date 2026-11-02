#!/bin/sh
# Test: write_vhdl memory with non-zero start_offset
# A Verilog memory declared with a non-zero base index (e.g. [4:7]) produces
# an RTLIL $mem with start_offset=4. The generated VHDL array type must reflect
# this: array(4 to 7), not array(0 to 3). Without the fix, addresses are wrong
# by start_offset, producing silently incorrect reads and writes.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../../rename/common.sh"
check_tools

write_verilog ram_offset.v << 'EOF'
module ram_offset(
    input        clk,
    input  [1:0] addr,
    input  [7:0] data_in,
    input        we,
    output reg [7:0] data_out
);
  // Array indices 4..7 -> start_offset=4, size=4
  reg [7:0] mem [4:7];
  always @(posedge clk) begin
    if (we) mem[addr + 4] <= data_in;
    data_out <= mem[addr + 4];
  end
endmodule
EOF

(cd "$WORK" && yosys -m "$PLUGIN" \
    -p "read_verilog ram_offset.v; proc; opt; write_vhdl ram_offset.vhd") \
    >"$WORK/yosys.log" 2>&1 || {
    echo "FAIL: write_vhdl failed"
    cat "$WORK/yosys.log" >&2
    exit 1
}

assert_has_vhdl ram_offset.vhd "entity ram_offset"

# The array type must use 4 as the lower bound, not 0.
if ! grep -q "array(4 to 7)" "$WORK/ram_offset.vhd"; then
    echo "FAIL: expected 'array(4 to 7)' in generated VHDL"
    grep "array(" "$WORK/ram_offset.vhd" >&2
    exit 1
fi

if command -v "$GHDL" >/dev/null 2>&1; then
    (cd "$WORK" && "$GHDL" -a --std=08 ram_offset.vhd) || {
        echo "FAIL: GHDL cannot parse output"
        exit 1
    }
fi

echo "PASS: memories_offset"
