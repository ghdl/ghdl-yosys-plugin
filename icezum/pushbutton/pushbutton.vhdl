library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pushbutton is
  port (sw1 : in std_logic;
        led0, led7 : out std_logic);
end pushbutton;

architecture synth of pushbutton is
begin
  led0 <= sw1;
  led7 <= not sw1;
end synth;
