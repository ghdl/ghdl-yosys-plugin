library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pushbutton_and is
  port (sw1, sw2 : in std_logic;
        led0, led7 : out std_logic);
end pushbutton_and;

architecture synth of pushbutton_and is

signal a : std_logic;

begin
  a <= sw1 and sw2;
  led0 <= a;
  led7 <= not a;
end synth;
