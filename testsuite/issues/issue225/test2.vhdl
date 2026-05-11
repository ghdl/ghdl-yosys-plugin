library ieee;
use ieee.std_logic_1164.all;

entity test2 is
port (
	a_i : in std_logic;
	b_io : out std_logic;
	c_io : inout std_logic
);
end entity;

architecture rtl of test2 is
begin
	b_io <= a_i;
	c_io <= a_i;
end architecture;
