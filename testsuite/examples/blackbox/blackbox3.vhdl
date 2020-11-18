library ieee;
use ieee.std_logic_1164.all;

entity blackbox3 is
  port (a, b : std_logic;
        o : out std_logic);
end;

architecture behav of blackbox3 is
  component \lib__cell__box2.3\ is
    port (a, b : std_logic;
          \O\ : out std_logic);
  end component;
begin
  inst: \lib__cell__box2.3\
    port map (a => a, b => b, \O\ => o);
end behav;

