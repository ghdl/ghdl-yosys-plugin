library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity leds is
  port (clk : in std_logic;
        led1, led2, led3, led4, led5, led6, led7, led8 : out std_logic);
end leds;
