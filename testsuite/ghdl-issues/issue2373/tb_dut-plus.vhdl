library ieee;
use ieee.std_logic_1164.all;

entity tb_dut is
	port(
		clk_in: in std_logic;

		dut1_a1_in: in std_logic;
		dut1_b1_out: out std_logic;
		dut1_a2_in: in std_logic;
		dut1_b2_out: out std_logic;

		dut2_a1_in: in std_logic;
		dut2_b1_out: out std_logic;
		dut2_a2_in: in std_logic;
		dut2_b2_out: out std_logic
	);
end;

architecture tb of tb_dut is
begin
	dut_1: entity work.dut
		port map(
			clk_in => clk_in,
	                a1_in => dut1_a1_in,
			b1_out => dut1_b1_out,
			a2_in => dut1_a2_in,
			b2_out => dut1_b2_out
		);

	dut_2: entity work.dut
		port map(
			clk_in => clk_in,
			a1_in => dut2_a1_in,
			b1_out => dut2_b1_out,
			a2_in => dut2_a2_in,
			b2_out => dut2_b2_out
		);



	default clock is rising_edge(clk_in);

--	stability_1: assert 
--	  {(dut1_a1_in = dut2_a1_in and dut1_a2_in = dut2_a2_in)[+];
	  -- {(dut1_a1_in = dut2_a1_in and dut1_a2_in = dut2_a2_in)[*1 to inf];
--	  	dut1_a1_in /= dut2_a1_in and dut1_a2_in = dut2_a2_in} |->
--	  {dut1_b1_out = dut2_b1_out}!;

	stability_2: assert 
		{(dut1_a1_in = dut2_a1_in and dut1_a2_in = dut2_a2_in)[+];
		-- {(dut1_a1_in = dut2_a1_in and dut1_a2_in = dut2_a2_in)[*1 to inf];
			dut1_a1_in = dut2_a1_in and dut1_a2_in /= dut2_a2_in} |->
		{dut1_b2_out = dut2_b2_out}!;

end;

