library ieee;
use ieee.std_logic_1164.all;

entity negadff is
	port(
		clk : in std_logic;
                rst : in std_logic;
		d : in std_logic;
		q : out std_logic
	);
end entity;

architecture arch of negadff is
begin
	process (clk, rst)
	begin
                if rst = '1' then
                        q <= '0';
		elsif falling_edge(clk) then
			q <= d;
		end if;
	end process;
end architecture;
