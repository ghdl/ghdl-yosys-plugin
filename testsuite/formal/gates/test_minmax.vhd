library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ent is
	port (
		clk : in std_logic;
		a : in std_logic_vector(7 downto 0);
		b : in std_logic_vector(7 downto 0);
		min_sgn : out signed(7 downto 0);
		max_sgn : out signed(7 downto 0);
		min_uns : out unsigned(7 downto 0);
		max_uns : out unsigned(7 downto 0)
	);
end;

architecture a of ent is
begin
	process(clk)
	begin
		if rising_edge(clk) then
			min_sgn <= minimum(signed(a), signed(b));
			max_sgn <= maximum(signed(a), signed(b));

			min_uns <= minimum(unsigned(a), unsigned(b));
			max_uns <= maximum(unsigned(a), unsigned(b));
		end if;
	end process;

	formal: block
		signal prev_a : std_logic_vector(7 downto 0);
		signal prev_b : std_logic_vector(7 downto 0);
		signal has_run : std_logic := '0';
	begin
		process(clk)
		begin
			if rising_edge(clk) then
				has_run <= '1';
				prev_a <= a;
				prev_b <= b;
			end if;
		end process;

		default clock is rising_edge(clk);
		assert eventually! has_run;

		assert always has_run and signed(prev_a) <= signed(prev_b) ->
			min_sgn = signed(prev_a) and max_sgn = signed(prev_b);
		assert always has_run and signed(prev_a) >= signed(prev_b) ->
			min_sgn = signed(prev_b) and max_sgn = signed(prev_a);

		assert always has_run and unsigned(prev_a) <= unsigned(prev_b) ->
			min_uns = unsigned(prev_a) and max_uns = unsigned(prev_b);
		assert always has_run and unsigned(prev_a) >= unsigned(prev_b) ->
			min_uns = unsigned(prev_b) and max_uns = unsigned(prev_a);
	end block;
end;
