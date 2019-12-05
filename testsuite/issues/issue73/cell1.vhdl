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

