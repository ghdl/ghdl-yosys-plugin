#!/bin/sh
# Test: write_vhdl memory with byte enables
# Verifies that per-byte write enables produce separate conditional assignments.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../../rename/common.sh"
check_tools

write_verilog ram_be.v << 'EOF'
module ram_be(
    input clk,
    input [7:0] addr,
    input [31:0] data_in,
    input [3:0] we,
    output reg [31:0] data_out
);
  reg [31:0] mem [0:255];
  always @(posedge clk) begin
    if (we[0]) mem[addr][ 7: 0] <= data_in[ 7: 0];
    if (we[1]) mem[addr][15: 8] <= data_in[15: 8];
    if (we[2]) mem[addr][23:16] <= data_in[23:16];
    if (we[3]) mem[addr][31:24] <= data_in[31:24];
    data_out <= mem[addr];
  end
endmodule
EOF

(cd "$WORK" && yosys -m "$PLUGIN" \
    -p "read_verilog ram_be.v; proc; opt; write_vhdl ram_be.vhd") \
    >"$WORK/yosys.log" 2>&1 || {
    echo "FAIL: write_vhdl byte-enable memory failed"
    cat "$WORK/yosys.log" >&2
    exit 1
}

assert_has_vhdl ram_be.vhd "entity ram_be"

# Check that at least two separate 'if' blocks appear in the write process,
# confirming per-byte conditional assignment (not one monolithic block).
count=$(grep -c "^  *if " "$WORK/ram_be.vhd" || true)
if [ "$count" -lt 2 ]; then
    echo "FAIL: expected multiple if-blocks for byte enables, got $count"
    cat "$WORK/ram_be.vhd" >&2
    exit 1
fi

if command -v "$GHDL" >/dev/null 2>&1; then
    (cd "$WORK" && "$GHDL" -a --std=08 ram_be.vhd) || {
        echo "FAIL: GHDL cannot parse byte-enable RAM output"
        exit 1
    }
fi

echo "PASS: memories_byteen"
