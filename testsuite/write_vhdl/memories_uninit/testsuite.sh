#!/bin/sh
# Test: write_vhdl -uninit option for partially-initialised memories
#
# A ROM with only the first two words initialised (words 2 and 3 are not).
# The -uninit flag controls what value is emitted for uninitialised bits:
#   -uninit 0  (default): emit '0' -- safe for synthesis, no X propagation
#   -uninit X          : emit 'X' -- propagating unknown for X-based sim
#   -uninit -          : emit '-' -- synthesis don't-care
#
# The test checks that the generated VHDL contains the expected characters
# and that GHDL can parse all three variants.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../../rename/common.sh"
check_tools

write_verilog rom.v << 'EOF'
module rom(
    input  [1:0] addr,
    output reg [7:0] data
);
  // 4-word ROM; only words 0 and 1 are initialised
  reg [7:0] mem [0:3];
  initial begin
    mem[0] = 8'hAA;
    mem[1] = 8'h55;
    // mem[2] and mem[3] are not initialised
  end
  always @(*) data = mem[addr];
endmodule
EOF

run_variant() {
    local variant="$1"
    local flag="$2"
    local expected_char="$3"

    (cd "$WORK" && yosys -m "$PLUGIN" \
        -p "read_verilog rom.v; proc; opt; memory_collect; write_vhdl $flag rom_${variant}.vhd") \
        >"$WORK/yosys_${variant}.log" 2>&1 || {
        echo "FAIL: write_vhdl $flag failed"
        cat "$WORK/yosys_${variant}.log" >&2
        return 1
    }

    assert_has_vhdl "rom_${variant}.vhd" "entity rom"

    # The uninit character should appear inside the aggregate initializer.
    # Words 2 and 3 are entirely uninitialised, so their 8 bits should all
    # use the uninit_val character.  Check that the file contains a word
    # consisting entirely of that character (8 identical chars inside quotes).
    expected_word="$(printf '%0.s'"$expected_char" 1 2 3 4 5 6 7 8)"
    if ! grep -qF "\"$expected_word\"" "$WORK/rom_${variant}.vhd"; then
        echo "FAIL ($variant): expected uninit word '\"$expected_word\"' not found"
        grep '"' "$WORK/rom_${variant}.vhd" | head -5 >&2
        return 1
    fi

    if command -v "$GHDL" >/dev/null 2>&1; then
        (cd "$WORK" && "$GHDL" -a --std=08 "rom_${variant}.vhd") || {
            echo "FAIL ($variant): GHDL cannot parse output"
            return 1
        }
    fi
    return 0
}

ok=1
run_variant default ""        "0" || ok=0
run_variant uninit0 "-uninit 0" "0" || ok=0
run_variant uninitX "-uninit X" "X" || ok=0
run_variant uninitd "-uninit -" "-" || ok=0

[ $ok -eq 1 ] && echo "PASS: memories_uninit" || exit 1
