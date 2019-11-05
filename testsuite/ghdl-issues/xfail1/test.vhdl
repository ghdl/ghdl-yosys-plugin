library ieee;
use ieee.std_logic_1164.all;

entity test is
    port(
        clk          : in std_logic
        );
end entity test;

architecture behaviour of test is
begin
    clk <= '1';
end architecture behaviour;
