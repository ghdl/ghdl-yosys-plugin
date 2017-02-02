library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--  Led positions
--
--  I         D3
--  r
--  D     D2  D5  D4
--  A
--            D1
--
entity leds is
  port (clk : in std_logic;
        led1, led2, led3, led4, led5 : out std_logic);
end leds;
