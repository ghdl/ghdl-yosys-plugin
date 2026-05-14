#!/bin/sh
# Test 8: Array of record port
# GHDL packs these into a single flat vector with no bracket notation.
# The rename pass should leave these ports untouched.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../common.sh"
check_tools

write_vhdl pkg.vhd << 'EOF'
library ieee;
use ieee.std_logic_1164.all;
package t08_pkg is
  type bus_i_t is record
    en : std_logic;
    d  : std_logic_vector(7 downto 0);
  end record;
  type bus_i_v_t is array (natural range <>) of bus_i_t;
  type bus_o_t is record
    ack : std_logic;
    d   : std_logic_vector(7 downto 0);
  end record;
  type bus_o_v_t is array (natural range <>) of bus_o_t;
end package;
EOF

write_vhdl dut.vhd << 'EOF'
library ieee;
use ieee.std_logic_1164.all;
use work.t08_pkg.all;
entity dut is port (
  clk : in  std_logic;
  bi  : in  bus_i_v_t(0 to 2);
  bo  : out bus_o_v_t(0 to 2));
end dut;
architecture rtl of dut is
begin
  gen: for i in 0 to 2 generate
    bo(i).ack <= bi(i).en;
    bo(i).d   <= bi(i).d;
  end generate;
end rtl;
EOF

ghdl_analyze pkg.vhd dut.vhd

# GHDL packs these into flat vectors: no bracket-escaped names
run_norename dut
assert_has_port before.v bi
assert_has_port before.v bo
assert_has_port before.v clk

# After rename: flat-packed ports should be untouched
run_ghdl_rename dut
assert_has_port out.v bi
assert_has_port out.v bo
assert_has_port out.v clk

clean
echo "PASS: t08_array_of_record"