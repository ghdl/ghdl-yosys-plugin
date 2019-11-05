library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vector is
    port (
        s : out signed(127 downto 0);
        u : out unsigned(127 downto 0)
        );
end entity vector;

architecture synth of vector is
begin
    s <= signed'(x"ffff000000fffff0") * signed'(x"fff0000ffff00000");
    u <= unsigned'(x"ffff000000fffff0") * unsigned'(x"fff0000ffff00000");
end synth;
