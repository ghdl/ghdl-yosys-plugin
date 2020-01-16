library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity led_on is
  port (led0, led1, led2, led3, led4, led5, led6, led7 : out std_logic);
end led_on;

architecture test of led_on is
begin
  -- Turn on the Led0
  led0 <= '1';
  -- Turn off the other leds
  (led1, led2, led3, led4, led5, led6, led7) <= std_logic_vector'("0000000");
end test;
