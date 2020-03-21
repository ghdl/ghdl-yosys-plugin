library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ent is
	port (
		clk : in std_logic;
		a : in signed(7 downto 0);
		b : out signed(7 downto 0)
	);
end;

architecture a of ent is
begin
	process(clk)
	begin
		if rising_edge(clk) then
			b <= abs a;
		end if;
	end process;

	formal: block
		signal last_a : signed(7 downto 0);
		signal has_run : std_logic := '0';
	begin
		process(clk)
		begin
			if rising_edge(clk) then
				has_run <= '1';
				last_a <= a;
			end if;
		end process;

		default clock is rising_edge(clk);
		assert always has_run -> b >= 0 or (last_a = x"80" and last_a = b);
	end block;
end;
