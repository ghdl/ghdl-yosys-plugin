library ieee;
use ieee.std_logic_1164.all;

entity repro is
  port (i : std_logic;
        o : out std_logic);
end;

architecture behav of repro is
begin
  process(i)
    variable v : std_logic;
  begin
    o <= i or v;
  end process;
end behav;
