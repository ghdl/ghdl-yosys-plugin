library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity counter8 is
  port (clk : in std_logic;
        led0 : out std_logic);
end counter8;

architecture synth of counter8 is
  
begin

  process (clk)
    variable temp : unsigned (7 downto 0);
  begin
    if rising_edge(clk) then
      temp:= temp + 1;
      led0 <= temp(0);
    end if;
  end process;

end synth;
