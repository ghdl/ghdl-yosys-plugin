library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vector is
    port (
        u : out signed(63 downto 0)
        );
end entity vector;

architecture synth of vector is
begin
    u <= -signed'(x"0ffffffffffffff0");
end synth;
