library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vector is
    port (v: out integer
          );
end vector;

architecture synth of vector is

begin
    v <= to_integer(unsigned'(x"7fffffff")) mod 64;
end synth;
