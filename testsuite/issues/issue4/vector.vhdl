library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vector is
  port (led0: out std_logic);
end vector;

architecture synth of vector is

signal v : std_logic_vector(7 downto 0);

begin
  v <= std_logic_vector'("10101010");
  led0 <= v(0);
end synth;
