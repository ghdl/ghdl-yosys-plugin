library ieee;
use ieee.std_logic_1164.all;

entity blackbox1 is
  port (a, b : std_logic;
        o : out std_logic);
end blackbox1;

architecture behav of blackbox1 is
  component my_blackbox is
    port (a, b : std_logic;
          o : out std_logic);
  end component;
begin
  inst: my_blackbox
    port map (a => a, b => b, o => o);
end behav;

