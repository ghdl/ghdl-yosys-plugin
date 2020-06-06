library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ent is
	port (
		clk : in std_logic;
		a : in std_logic_vector(7 downto 0);
		b : in std_logic_vector(7 downto 0);
		rem_sgn : out signed(7 downto 0);
		mod_sgn : out signed(7 downto 0);
		rem_uns : out unsigned(7 downto 0);
		mod_uns : out unsigned(7 downto 0)
	);
end;

architecture a of ent is
begin
	process(clk)
	begin
		if rising_edge(clk) then
			rem_sgn <= signed(a) rem signed(b);
			mod_sgn <= signed(a) mod signed(b);

			rem_uns <= unsigned(a) rem unsigned(b);
			mod_uns <= unsigned(a) mod unsigned(b);
		end if;
	end process;

	formal: block
		signal prev_a : std_logic_vector(7 downto 0);
		signal prev_b : std_logic_vector(7 downto 0);
		signal has_run : std_logic := '0';

		function same_sign(x, y : signed) return boolean is
		begin
			return x = 0 or y = 0 or (x > 0) = (y > 0);
		end function;

		function longer(x : signed) return signed is
		begin
			return resize(x, x'length+1);
		end function;

		-- artificial flooring integer division, constructed from native
		-- truncating integer division operator (/)
		function floordiv(x, y : signed) return signed is
		begin
			-- same signs on inputs will give positive result - rounded in same
			-- direction as truncating division
			if same_sign(x, y) then
				return x / y;
			-- otherwise, increase the absolute value of x by abs(y)-1
			elsif x < 0 then
				-- x is negative, y is positive
				return (x - (y - 1)) / y;
			else
				-- x is positive, y is negative
				return (x - (y + 1)) / y;
			end if;
		end function;
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

		mod_sgn_sign: assert always has_run -> same_sign(signed(prev_b), mod_sgn);
		mod_sgn_correct: assert always has_run ->
			floordiv(
				longer(signed(prev_a)),
				longer(signed(prev_b))
			)
			* signed(prev_b)
			+ mod_sgn = signed(prev_a);

		rem_sgn_sign: assert always has_run -> same_sign(signed(prev_a), rem_sgn);
		rem_sgn_correct: assert always has_run ->
			longer(signed(prev_a)) / longer(signed(prev_b))
			* signed(prev_b)
			+ rem_sgn = signed(prev_a);

		-- calculating modulo from remainder
		assert always has_run ->
			(rem_sgn = 0 and mod_sgn = rem_sgn) or
			(same_sign(signed(prev_a), signed(prev_b)) and mod_sgn = rem_sgn) or
			mod_sgn = rem_sgn + signed(prev_b);

		uns_mod_correct: assert always has_run ->
			unsigned(prev_a) / unsigned(prev_b) * unsigned(prev_b) + mod_uns = unsigned(prev_a);
		unsigned_equal: assert always has_run -> mod_uns = rem_uns;
	end block;
end;
