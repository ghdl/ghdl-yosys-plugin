library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity repro is
  port (
    clk_in: in std_logic;
    sreset_in: in std_logic;
		
    a_in: in std_logic;		
    b_out: out std_logic
    );
end;

architecture rtl of repro is
	signal pipe: std_logic_vector(3 downto 0) := (others => '0');
begin
  process(clk_in)
  begin
    if rising_edge(clk_in) then
      if false and sreset_in = '1' then
        pipe <= (others => '0');
        b_out <= '0';
      else
        b_out <= pipe(3);
        pipe <= pipe(2 downto 0) & a_in;
      end if;
    end if;
  end process;

  default clock is rising_edge(clk_in);
	
--  a_1: assume {sreset_in[*2]};

  --  a_in must be stable for 2 cycles.prove_2: mode prove
  a_2: restrict {not a_in; [*]};
  a_3: assume always {not a_in; a_in} |=> {a_in};
	
  f_1: assert always {b_out='0'; b_out='1'} |=> {b_out='1'}; -- abort sreset_in;
	
--	f_2: assert always state <= 31 abort sreset_in;
end;
