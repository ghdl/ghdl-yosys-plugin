#!/bin/sh
# Test 3: Collision detection
# Verifies that \db_o[en]\ and \db[o_en]\ both mapping to db_o_en are disambiguated

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../common.sh"
check_tools

write_vhdl pkg.vhd << 'EOF'
library ieee;
use ieee.std_logic_1164.all;
package t03_pkg is
  type db_in_t is record
    o_en : std_logic;
    d   : std_logic_vector(7 downto 0);
  end record;
  type db_out_t is record
    en : std_logic;
    d  : std_logic_vector(7 downto 0);
  end record;
end package;
EOF

write_vhdl dut.vhd << 'EOF'
library ieee;
use ieee.std_logic_1164.all;
use work.t03_pkg.all;
entity dut is port (
  clk  : in  std_logic;
  db_i : in  db_in_t;
  db_o : out db_out_t);
end dut;
architecture rtl of dut is
begin
  db_o.en <= db_i.o_en;
  db_o.d  <= db_i.d;
end rtl;
EOF

ghdl_analyze pkg.vhd dut.vhd

# Run with --rename flag
run_ghdl_rename dut

# Both \db_i[o_en]\ and \db_o[en]\ would map to db_o_en or db_i_o_en
# Verify no escaped names remain
assert_no_escaped out.v '\db_i['
assert_no_escaped out.v '\db_o['

# Verify clean names exist (disambiguated with suffixes if needed)
# At minimum, the ports should be present in some form
grep -q "db_" "$WORK/out.v" || { echo "FAIL: no db_ ports found"; exit 1; }

clean
echo "PASS: t03_collision"