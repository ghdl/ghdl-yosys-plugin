library ieee;
use ieee.std_logic_1164.all;

entity latch is
  port (
    signal clk          : in std_logic;
    signal data         : in std_logic
    );
end entity;



architecture rtl of latch is
  signal other         : std_logic := '0';        
begin
  
  default clock is rising_edge(clk);
  assert always {true}
    |=> next (data = other);  
end architecture;
