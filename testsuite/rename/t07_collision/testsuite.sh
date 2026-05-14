#!/bin/sh
# Test 7: Underscore ambiguity / name collision
# \db_o[en]\ and \db[o_en]\ both -> db_o_en under naive renaming.
# The pass must detect this and disambiguate.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../common.sh"
check_tools

write_vhdl pkg.vhd << 'EOF'
library ieee;
use ieee.std_logic_1164.all;
package t07_pkg is
  type rec_a_t is record
    en : std_logic;
    d  : std_logic_vector(3 downto 0);
  end record;
  type rec_b_t is record
    o_en : std_logic;
    o_d  : std_logic_vector(3 downto 0);
  end record;
end package;
EOF

write_vhdl dut.vhd << 'EOF'
library ieee;
use ieee.std_logic_1164.all;
use work.t07_pkg.all;
entity dut is port (
  db_o : in  rec_a_t;
  db   : in  rec_b_t;
  y    : out std_logic);
end dut;
architecture rtl of dut is
begin
  y <= db_o.en xor db.o_en;
end rtl;
EOF

ghdl_analyze pkg.vhd dut.vhd

# Verify GHDL produces the colliding mangled names
run_norename dut
assert_has_escaped before.v '\db_o[en]'
assert_has_escaped before.v '\db[o_en]'

# After rename: no escaped names remain, all ports present and distinct
run_ghdl_rename dut
assert_no_escaped out.v '\db_o[en]'
assert_no_escaped out.v '\db[o_en]'

port_count=$(grep -cE '^\s*(input|output)' "$WORK/out.v")
if [ "$port_count" -lt 3 ]; then
    echo "FAIL: expected at least 3 port declarations, got $port_count"
    dump out.v
    exit 1
fi

clean
echo "PASS: t07_collision"