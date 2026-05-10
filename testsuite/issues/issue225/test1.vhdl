library ieee;
use ieee.std_logic_1164.all;

entity test1 is
port (
	a_i : in std_logic;
	b_io : inout std_logic;
	c_io : inout std_logic
);
end entity;

architecture rtl of test1 is
begin

	b_io <= a_i;
	c_io <= a_i;

end architecture;
