library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ent is
	port (
		clk : in std_logic;
		a : in std_logic_vector(1 downto 0);
		b : out std_logic_vector(1 downto 0)
	);
end entity;

architecture a of ent is
begin
	process(clk)
	begin
		if rising_edge(clk) then
			case a is
				when "00" =>
					b <= "01";
				when "01" =>
					b <= "10";
				when "11" =>
					b <= "00";
				when others =>
					b <= "11";
			end case;
		end if;
	end process;

	formal: block
		signal has_run : std_logic := '0';
		signal prev_a : std_logic_vector(1 downto 0);
	begin
		process(clk)
		begin
			if rising_edge(clk) then
				prev_a <= a;
				has_run <= '1';
			end if;
		end process;

		default clock is rising_edge(clk);
		assert always has_run -> unsigned(prev_a) + 1 = unsigned(b);
	end block;
end architecture;
