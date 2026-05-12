#!/bin/sh
# Test 9: Blackbox cell with mangled port names
# The sub-module is loaded as a Verilog blackbox with already-mangled ports.
# vhdl_rename must update the cell connection keys even though
# the module body is absent.
source "$(dirname "$0")/../common.sh"
check_tools

# The "pre-built" blackbox: a Verilog stub with GHDL-mangled ports.
cat > "$WORK/macro.v" << 'EOF'
(* blackbox *)
module my_macro (
  input  clk,
  input  \bi[en] ,
  input  [7:0] \bi[d] ,
  output \bo[ack] ,
  output [7:0] \bo[d]
);
endmodule
EOF

write_vhdl pkg.vhd << 'EOF'
library ieee;
use ieee.std_logic_1164.all;
package t09_pkg is
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

write_vhdl top.vhd << 'EOF'
library ieee;
use ieee.std_logic_1164.all;
use work.t09_pkg.all;

entity top is port (
  clk : in  std_logic;
  bi  : in  bus_i_t;
  bo  : out bus_o_t);
end top;

architecture rtl of top is
  component my_macro is port (
    clk : in  std_logic;
    bi  : in  bus_i_t;
    bo  : out bus_o_t);
  end component;
begin
  u_macro : my_macro
    port map (clk => clk, bi => bi, bo => bo);
end rtl;
EOF

ghdl_analyze pkg.vhd top.vhd

# Verify GHDL produces escaped names in cell connections
(cd "$WORK" && yosys -m "$PLUGIN" \
  -p "read_verilog -sv macro.v; ghdl top; write_verilog -noattr before.v") \
  >"$WORK/yosys_nr.log" 2>&1 || {
    echo "FAIL: yosys (no rename) failed"
    cat "$WORK/yosys_nr.log" >&2
    exit 1
}

assert_has_escaped before.v '\bi[en]'
assert_has_escaped before.v '\bo[ack]'

# Test with --rename flag: cell connections must be updated
(cd "$WORK" && yosys -m "$PLUGIN" \
  -p "read_verilog -sv macro.v; ghdl --rename top; write_verilog -noattr out.v") \
  >"$WORK/yosys.log" 2>&1 || {
    echo "FAIL: yosys --rename failed"
    cat "$WORK/yosys.log" >&2
    exit 1
}

# Top-level ports renamed
assert_has_port out.v bi_en
assert_has_port out.v bi_d
assert_has_port out.v bo_ack
assert_has_port out.v bo_d
# No escaped names anywhere
assert_no_escaped out.v '\bi[en]'
assert_no_escaped out.v '\bi[d]'
assert_no_escaped out.v '\bo[ack]'
assert_no_escaped out.v '\bo[d]'

clean
echo "PASS: t09_blackbox"