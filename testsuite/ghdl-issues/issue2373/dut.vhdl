library ieee;
use ieee.std_logic_1164.all;

entity dut is
	port(
		clk_in: in std_logic;

		a1_in: in std_logic;
		b1_out: out std_logic;

		a2_in: in std_logic;
		b2_out: out std_logic
	);
end;

architecture rtl of dut is
	signal cnt: integer range 0 to 20 := 0;

	signal a2_prev: std_logic := '0';
begin
	process(clk_in)
	begin
		if rising_edge(clk_in) then
			if cnt /= 20 then
				cnt <= cnt + 1;
			end if;
		end if;
	end process;

	process(clk_in)
	begin
		if rising_edge(clk_in) then
			a2_prev <= a2_in;

			b1_out <= not a1_in;
			if cnt = 20 then
				b1_out <= a1_in;
			end if;
		end if;
	end process;

	process(all)
	begin
		b2_out <= a2_prev;
		if cnt = 20 then
			b2_out <= not a2_in;
		end if;
		b2_out <= not a2_in;
	end process;
end;

