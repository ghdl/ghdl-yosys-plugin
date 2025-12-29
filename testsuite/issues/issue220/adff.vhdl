library ieee;
use ieee.std_logic_1164.all;

entity dff is
  port (
    clk : in  std_logic;
    ce  : in  std_logic;
    din : in  std_logic;
    set : in  std_logic;
    res : in  std_logic;
    q   : out std_logic
 );
end;

architecture rtl of dff is

begin
  process (clk, set, res)
  begin
    if res = '1' then
      q <= '0';
    elsif set = '1' then
      q <= '1';
    elsif rising_edge(clk) then
      if ce = '1' then
        q <= din;
      end if;
    end if;
  end process;
end;
