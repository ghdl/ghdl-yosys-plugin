#!/bin/sh
# Test 4: Comparison of vhdl_rename pass vs --rename flag
# Verifies both produce identical module port lists

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../common.sh"
check_tools

write_vhdl pkg.vhd << 'EOF'
library ieee;
use ieee.std_logic_1164.all;
package t04_pkg is
  type bus_i_t is record
    en : std_logic;
    d  : std_logic_vector(3 downto 0);
  end record;
end package;
EOF

write_vhdl dut.vhd << 'EOF'
library ieee;
use ieee.std_logic_1164.all;
use work.t04_pkg.all;
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

# Method 1: explicit vhdl_rename pass
(cd "$WORK" && yosys -m "$PLUGIN" \
    -p "ghdl dut; vhdl_rename; write_verilog -noattr out_explicit.v") \
    >"$WORK/yosys1.log" 2>&1 || {
    echo "FAIL: explicit vhdl_rename failed"
    cat "$WORK/yosys1.log" >&2
    exit 1
}

# Method 2: --rename flag
(cd "$WORK" && yosys -m "$PLUGIN" \
    -p "ghdl --rename dut; write_verilog -noattr out_flag.v") \
    >"$WORK/yosys2.log" 2>&1 || {
    echo "FAIL: --rename flag failed"
    cat "$WORK/yosys2.log" >&2
    exit 1
}

# Compare port declarations (grep for input/output lines)
# Both should produce identical port lists after rename
explicit_ports=$(grep -E '^\s*(input|output)' "$WORK/out_explicit.v" | sort)
flag_ports=$(grep -E '^\s*(input|output)' "$WORK/out_flag.v" | sort)

if [ "$explicit_ports" != "$flag_ports" ]; then
    echo "FAIL: --rename and explicit vhdl_rename produce different results"
    echo "=== explicit ==="
    echo "$explicit_ports"
    echo "=== flag ==="
    echo "$flag_ports"
    exit 1
fi

clean
echo "PASS: t04_rename_equivalence"