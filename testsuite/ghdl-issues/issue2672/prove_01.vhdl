library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity prove_01 is
	port(
		clk_in: in std_logic;
		sreset_in: in std_logic;
		
		a_in: in std_logic;
		
		b_out: out std_logic
	);
end;

architecture rtl of prove_01 is
	signal state: unsigned(7 downto 0);
begin
	process(clk_in)
	begin
		if rising_edge(clk_in) then
			if a_in = '1' then
				state <= (state + 1) mod 32;
			end if;
			if state = 0 then
				b_out <= a_in;
			else
				b_out <= '0';
			end if;
			
			if sreset_in = '1' then
				state <= (others => '0');
				b_out <= '0';
			end if;
		end if;
	end process;
	
	default clock is rising_edge(clk_in);
	
	a_1: assume {sreset_in[*2]};
	a_2: assume {not sreset_in; sreset_in} |=> {sreset_in};
	a_3: assume always {not a_in; a_in} |=> {a_in};
	a_4: assume always {a_in; not a_in} |=> {not a_in};
	
	f_1: assert always {b_out='1'} |=> {b_out='0'[*31]} abort prev(sreset_in);
end;
