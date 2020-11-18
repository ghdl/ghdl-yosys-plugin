library ieee;
use ieee.std_logic_1164.all;

entity blackbox2 is
  port (a, b : std_logic;
        o : out std_logic);
end;

architecture behav of blackbox2 is
  component my_blackbox is
    port (a, b : std_logic;
          \OUT\ : out std_logic);
  end component;
begin
  inst: my_blackbox
    port map (a => a, b => b, \OUT\ => o);
end behav;

