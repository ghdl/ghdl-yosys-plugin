library ieee;
use ieee.std_logic_1164.all;

entity psl_p_plus is
	generic(
		DATA_BITS: natural := 8
	);
	port(
		clk_in: in std_logic;
		
		a_in: in std_logic;
		b_in: in std_logic;
		c_in: in std_logic
	);
end;

architecture psl of psl_p_plus is
begin
	default clock is rising_edge(clk_in);
	
	p_plus_psl: assert {a_in[+]; b_in} |-> {c_in};
end;
