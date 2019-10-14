library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vector is
  port (v: out signed(63 downto 0);
        u: out unsigned(63 downto 0));
end vector;

architecture synth of vector is

begin
  v <= signed'(x"0ffffffffffffff0")+(-1);
  u <= unsigned'(x"00ffffffffffff00")+4294967290;
end synth;
