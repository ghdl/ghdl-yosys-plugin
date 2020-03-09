library ieee;
use ieee.std_logic_1164.all;

entity loop1 is
  port (a : std_logic_vector (7 downto 0);
        o : out std_logic_vector (15 downto 0));
end;

architecture behav of loop1 is
  signal s : std_logic_vector (15 downto 0);
begin
  s <= a & s (15 downto 8);
  o <= s;
end behav;
