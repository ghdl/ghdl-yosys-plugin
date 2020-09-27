library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vector is
  port (v: out signed(63 downto 0);
        u: out unsigned(63 downto 0));
end vector;

architecture synth of vector is
  signal v1 : signed (63 downto 0);
  signal u1 : unsigned (63 downto 0);

begin
  v1 <= x"0ffffffffffffff0";
  v <= v1+(-1);
  u1 <= x"00ffffffffffff00";
--  u <= u1 + (-6); -- +4294967290;
  u <= u1 + 6;
end synth;
