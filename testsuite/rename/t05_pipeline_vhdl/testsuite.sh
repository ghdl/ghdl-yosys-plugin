#!/bin/sh
# Test 5: Full pipeline test -- ghdl --rename followed by write_vhdl
# Verifies the complete VHDL → renamed RTLIL → VHDL netlist pipeline

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../common.sh"
check_tools

write_vhdl pkg.vhd << 'EOF'
library ieee;
use ieee.std_logic_1164.all;
package t05_pkg is
  type bus_i_t is record
    en : std_logic;
    d  : std_logic_vector(7 downto 0);
  end record;
end package;
EOF

write_vhdl dut.vhd << 'EOF'
library ieee;
use ieee.std_logic_1164.all;
use work.t05_pkg.all;
entity dut is port (
  clk : in  std_logic;
  bi  : in  bus_i_t);
end dut;
architecture rtl of dut is
begin
  process(clk) begin if rising_edge(clk) then null; end if; end process;
end rtl;
EOF

ghdl_analyze pkg.vhd dut.vhd

# Full pipeline: ghdl --rename + write_vhdl
(cd "$WORK" && yosys -m "$PLUGIN" \
    -p "ghdl --rename dut; write_vhdl out.vhd") \
    >"$WORK/yosys.log" 2>&1 || {
    echo "FAIL: full pipeline failed"
    cat "$WORK/yosys.log" >&2
    exit 1
}

# Verify output VHDL has clean port names (no escaped identifiers)
assert_has_vhdl out.vhd "bi_en"
assert_has_vhdl out.vhd "bi_d"
assert_has_vhdl out.vhd "clk"

# Verify no escaped bracket notation in the VHDL output
if grep -q '\\\[en\]' "$WORK/out.vhd" || grep -q '\\\[d\]' "$WORK/out.vhd"; then
    echo "FAIL: escaped brackets found in VHDL output"
    cat "$WORK/out.vhd"
    exit 1
fi

# Verify the output is valid VHDL (GHDL can parse it)
if command -v "$GHDL" >/dev/null 2>&1; then
    (cd "$WORK" && "$GHDL" -a --std=08 out.vhd) || {
        echo "FAIL: GHDL cannot parse the output VHDL"
        exit 1
    }
fi

clean
echo "PASS: t05_pipeline_vhdl"