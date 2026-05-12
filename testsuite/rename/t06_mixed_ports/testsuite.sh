#!/bin/sh
# Test 6: Mixed plain and record ports
# Verifies that plain std_logic ports are left unchanged
source "$(dirname "$0")/../common.sh"
check_tools

write_vhdl pkg.vhd << 'EOF'
library ieee;
use ieee.std_logic_1164.all;
package t06_pkg is
  type data_t is record
    en  : std_logic;
    d   : std_logic_vector(7 downto 0);
  end record;
end package;
EOF

write_vhdl dut.vhd << 'EOF'
library ieee;
use ieee.std_logic_1164.all;
use work.t06_pkg.all;
entity dut is port (
  clk   : in  std_logic;
  rst   : in  std_logic;
  di    : in  data_t;
  sel   : in  std_logic_vector(1 downto 0);
  y     : out std_logic);
end dut;
architecture rtl of dut is
begin
  y <= di.en and sel(0) and not rst;
end rtl;
EOF

ghdl_analyze pkg.vhd dut.vhd

# Verify GHDL produces mangled record ports and plain ports
run_norename dut
assert_has_port before.v clk
assert_has_port before.v rst
assert_has_port before.v sel
assert_has_port before.v y
assert_has_escaped before.v '\di[en]'
assert_has_escaped before.v '\di[d]'

# Test with --rename flag
run_ghdl_rename dut
assert_has_port out.v clk
assert_has_port out.v rst
assert_has_port out.v sel
assert_has_port out.v y
assert_has_port out.v di_en
assert_has_port out.v di_d
assert_no_escaped out.v '\di[en]'

clean
echo "PASS: t06_mixed_ports"