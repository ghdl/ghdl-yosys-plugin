library ieee;
use ieee.std_logic_1164.all;

entity cell1 is
  port (
    O: out std_logic
  );
end entity cell1;

architecture rtl of cell1 is
begin
  O <= '0';
end architecture rtl;

library ieee;
use ieee.std_logic_1164.all;

entity cell2 is
  port (
    O: out std_logic
  );
end entity cell2;

architecture rtl of cell2 is
begin
  O <= '1';
end architecture rtl;
