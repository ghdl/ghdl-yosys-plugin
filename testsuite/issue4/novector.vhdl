library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity no_vector is
  port (led0: out std_logic);
end no_vector;

architecture synth of no_vector is

signal nv : std_logic;

begin
  nv <= '1';
  led0 <= nv;
end synth;
