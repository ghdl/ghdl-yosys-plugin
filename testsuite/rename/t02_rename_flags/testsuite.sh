#!/bin/sh
# Test: --rename-verbose and --rename-map flags
# Verifies that --rename-verbose logs renames and --rename-map writes JSON

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../common.sh"
check_tools

write_vhdl pkg.vhd << 'EOF'
library ieee;
use ieee.std_logic_1164.all;
package t02_pkg is
  type bus_i_t is record
    en : std_logic;
    d  : std_logic_vector(7 downto 0);
  end record;
end package;
EOF

write_vhdl dut.vhd << 'EOF'
library ieee;
use ieee.std_logic_1164.all;
use work.t02_pkg.all;
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

# Test --rename-verbose: should log each rename
(cd "$WORK" && yosys -m "$PLUGIN" \
    -p "ghdl --rename-verbose dut" \
    ) >"$WORK/yosys.log" 2>&1 || {
    echo "FAIL: yosys --rename-verbose failed"
    cat "$WORK/yosys.log" >&2
    exit 1
}
if ! grep -q "bi\[en\].*->" "$WORK/yosys.log"; then
    echo "FAIL: --rename-verbose did not log renames"
    cat "$WORK/yosys.log"
    exit 1
fi

# Test --rename-map: should write a JSON map file
(cd "$WORK" && yosys -m "$PLUGIN" \
    -p "ghdl --rename --rename-map map.json dut" \
    ) >"$WORK/yosys.log" 2>&1 || {
    echo "FAIL: yosys --rename-map failed"
    cat "$WORK/yosys.log" >&2
    exit 1
}
if [ ! -f "$WORK/map.json" ]; then
    echo "FAIL: --rename-map did not create map.json"
    exit 1
fi
if ! grep -q '"old".*"\\\\bi\[en\]"' "$WORK/map.json" && \
   ! grep -q '"old".*"bi\[en\]"' "$WORK/map.json"; then
    echo "FAIL: map.json does not contain expected rename entries"
    cat "$WORK/map.json"
    exit 1
fi

clean
echo "PASS: t02_rename_flags"