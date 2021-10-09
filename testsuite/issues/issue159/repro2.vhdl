library ieee;
use ieee.std_logic_1164.all;

entity repro2 is
  port (i : std_logic;
        o : out std_logic);
end;

architecture behav of repro2 is
  signal v : std_logic;
begin
  process(i)
  begin
    o <= i or v;
  end process;
end behav;
