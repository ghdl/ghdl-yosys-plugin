library ieee;
use ieee.std_logic_1164.all;

entity negdff is
	port(
		clk : in std_logic;
		d : in std_logic;
		q : out std_logic
	);
end entity;

architecture arch of negdff is
begin
	process (clk)
	begin
		if falling_edge(clk) then
			q <= d;
		end if;
	end process;
end architecture;
