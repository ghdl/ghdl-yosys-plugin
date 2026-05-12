#!/bin/sh
# Test 1: Simple record port renaming
# Verifies \port[field]\ becomes port_field
# Also tests that --rename flag produces identical results to explicit vhdl_rename

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../common.sh"
check_tools

write_vhdl pkg.vhd << 'EOF'
library ieee;
use ieee.std_logic_1164.all;
package t01_pkg is
  type bus_i_t is record
    en : std_logic;
    d  : std_logic_vector(7 downto 0);
  end record;
  type bus_o_t is record
    ack : std_logic;
    d   : std_logic_vector(7 downto 0);
  end record;
end package;
EOF

write_vhdl dut.vhd << 'EOF'
library ieee;
use ieee.std_logic_1164.all;
use work.t01_pkg.all;
entity dut is port (
  clk : in  std_logic;
  bi  : in  bus_i_t;
  bo  : out bus_o_t);
end dut;
architecture rtl of dut is
begin
  bo.ack <= bi.en;
  bo.d   <= bi.d;
end rtl;
EOF

ghdl_analyze pkg.vhd dut.vhd

# Verify GHDL produces the expected mangling
run_norename dut
assert_has_escaped before.v '\bi[en]'
assert_has_escaped before.v '\bi[d]'
assert_has_escaped before.v '\bo[ack]'
assert_has_escaped before.v '\bo[d]'

# Test 1a: explicit vhdl_rename pass
run_rename dut
assert_has_port out.v bi_en
assert_has_port out.v bi_d
assert_has_port out.v bo_ack
assert_has_port out.v bo_d
assert_has_port out.v clk
assert_no_escaped out.v '\bi[en]'
assert_no_escaped out.v '\bo[ack]'

# Test 1b: --rename flag on ghdl command
run_ghdl_rename dut
assert_has_port out.v bi_en
assert_has_port out.v bi_d
assert_has_port out.v bo_ack
assert_has_port out.v bo_d
assert_has_port out.v clk
assert_no_escaped out.v '\bi[en]'
assert_no_escaped out.v '\bo[ack]'

clean
echo "PASS: t01_simple_record"