library ieee;
use ieee.std_logic_1164.all;

entity vector is
  port (led0, led1, led2, led3, led4, led5, led6, led7: out std_logic);
end vector;

architecture ref of vector is
  signal v : std_logic_vector(7 downto 0);
begin
  -- It works ok
  (led7, led6, led5, led4, led3, led2, led1, led0) <= std_logic_vector'("10101010");
end;
