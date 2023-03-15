library ieee;
use ieee.std_logic_1164.all;

entity compare_psl_p_plus is
    port(
        clk_in: in std_logic;
		a_in: in std_logic;
		b_in: in std_logic;
		c_in: in std_logic
    );
end;

architecture rtl of compare_psl_p_plus is
    component psl_p_plus is
        port(
            clk_in: in std_logic;
            a_in: in std_logic;
            b_in: in std_logic;
            c_in: in std_logic;
            \p_plus_psl.A\: out std_logic;
            \p_plus_psl.EN\: out std_logic
        );
    end component;
	
	signal first_cycle: std_logic := '1';
	signal nda_r0: std_logic := '0';
	signal nda_res: std_logic;

    signal p_plus_psl_a: std_logic;
    signal p_plus_psl_en: std_logic;
    signal p_plus_psl: std_logic;
begin
    dut: psl_p_plus
        port map(
            clk_in => clk_in,
            a_in => a_in,
            b_in => b_in,
            c_in => c_in,
            \p_plus_psl.A\ => p_plus_psl_a,
            \p_plus_psl.EN\ => p_plus_psl_en
        );
	
	p_plus_psl <= p_plus_psl_en and p_plus_psl_a;
	
	reference_model_sync_pr: process(clk_in)
	begin
		if rising_edge(clk_in) then
			first_cycle <= '0';
		
			nda_r0 <= '0';
			if first_cycle = '1' and a_in = '1' then
				nda_r0 <= '1';
			end if;
			if nda_r0 = '1' and a_in = '1' then
				nda_r0 <= '1';
			end if;
		end if;
	end process;
	
	reference_model_async_pr: process(all)
	begin
		nda_res <= '1';
		if nda_r0 = '1' and b_in = '1' and c_in = '0' then
			nda_res <= '0';
		end if;
	end process;
	
    
    default clock is rising_edge(clk_in);

    comparison_assert: postponed assert nda_res = p_plus_psl;

    cover_psl: cover {true; true; p_plus_psl = '0'};

    cover_psl_first: cover {true; true; [*]; p_plus_psl = '0'};
end;

