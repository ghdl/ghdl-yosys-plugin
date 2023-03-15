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
	signal all_inputs_equal: std_logic;
	signal a1_differ: std_logic;
	signal a2_differ: std_logic;

	signal b1_equal: std_logic;
	signal b2_equal: std_logic;
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

	-- Formal part =>

	process(all)
	begin
		all_inputs_equal <= '1';
		if dut1_a1_in /= dut2_a1_in or dut1_a2_in /= dut2_a2_in then
			all_inputs_equal <= '0';
		end if;

		a1_differ <= '0';
		if dut1_a1_in /= dut2_a1_in then
			a1_differ <= '1';
		end if;

		a2_differ <= '0';
		if dut1_a2_in /= dut2_a2_in then
			a2_differ <= '1';
		end if;

		b1_equal <= '0';
		if dut1_b1_out = dut2_b1_out then
			b1_equal <= '1';
		end if;

		b2_equal <= '0';
		if dut1_b2_out = dut2_b2_out then
			b2_equal <= '1';
		end if;
	end process;

	default clock is rising_edge(clk_in);

--	b1_nonasync: assert {all_inputs_equal[*1 to inf]; a1_differ} |-> {b1_equal};

	-- This _should_ generate an assert at cycle 20:
	b2_nonasync_1: assert {all_inputs_equal[*1 to inf]; a2_differ} |-> {b2_equal};

	-- This _should_ generate an assert at cycle 20:
--	b2_nonasync_2: assert {all_inputs_equal[+]; a2_differ} |-> {b2_equal};

	-- This generates an assert at cycle 20:
	-- b2_nonasync_3: assert {all_inputs_equal[*2 to inf]; a2_differ} |-> {b2_equal};

	-- This generates an assert at cycle 20:
	-- b2_nonasync_4: assert {all_inputs_equal[*0 to inf]; a2_differ} |-> {b2_equal};

	-- This generates an assert at cycle 20:
	-- b2_nonasync_5: assert {all_inputs_equal[*]; a2_differ} |-> {b2_equal};


	--cover_tester: cover {all_inputs_equal[*21]; a2_differ; all_inputs_equal[*5]};
end;
