#!/bin/sh
# Test 12: Record port containing an array-of-record field
#
# The outer record has a plain std_logic field (ctrl) and an array-of-record
# field (data : inner_arr_t).  GHDL expands the outer record but keeps the
# array-of-record field as a packed flat vector.
#
# Expected after vhdl_rename:
#   \p[ctrl]\  -> p_ctrl   (leaf std_logic, expanded)
#   \p[data]\  -> p_data   (packed vector, not further expanded)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../common.sh"
check_tools

write_vhdl pkg.vhd << 'EOF'
library ieee;
use ieee.std_logic_1164.all;
package t12_pkg is
  type inner_t is record
    a : std_logic;
    b : std_logic;
  end record;
  type inner_arr_t is array (0 to 1) of inner_t;
  type outer_t is record
    ctrl : std_logic;
    data : inner_arr_t;
  end record;
end package;
EOF

write_vhdl dut.vhd << 'EOF'
library ieee;
use ieee.std_logic_1164.all;
use work.t12_pkg.all;
entity dut is port (
  p  : in  outer_t;
  oa : out std_logic;
  ob : out std_logic;
  oc : out std_logic);
end dut;
architecture rtl of dut is
begin
  oa <= p.ctrl;
  ob <= p.data(0).a;
  oc <= p.data(1).b;
end rtl;
EOF

ghdl_analyze pkg.vhd dut.vhd

# Verify GHDL emits the expected mix: leaf ctrl + packed data vector
run_norename dut
assert_has_escaped before.v '\p[ctrl]'
assert_has_escaped before.v '\p[data]'
# Array sub-fields must NOT appear as individual ports
assert_no_escaped before.v '\p[data][0]'
assert_no_escaped before.v '\p[data][1]'

# After --rename: leaf expanded, packed vector renamed as-is
run_ghdl_rename dut
assert_has_port out.v p_ctrl
assert_has_port out.v p_data
assert_has_port out.v oa
assert_has_port out.v ob
assert_has_port out.v oc
assert_no_escaped out.v '\p[ctrl]'
assert_no_escaped out.v '\p[data]'

clean
echo "PASS: t12_record_with_array_field"