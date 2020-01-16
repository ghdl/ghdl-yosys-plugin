library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity counter is
  port (
    clk : in std_logic;
    led0, led1, led2, led3, led4, led5, led6, led7 : out std_logic
  );
end counter;

architecture synth of counter is
  signal clk_6hz : std_logic;
begin
  -- Presscaler
  prescaler: process(clk)
    variable timer : unsigned (20 downto 0) := (others=>'0');
  begin
    if rising_edge(clk) then
      timer := timer + 1;
      clk_6hz <= timer(20);
    end if;
  end process;

  -- 8 bits counter
  process (clk_6hz)
    variable temp : unsigned (7 downto 0);
  begin
    if rising_edge(clk_6hz) then
      temp:= temp + 1;
      -- Show the counter on the icezum Alhambra leds
      (led7, led6, led5, led4, led3, led2, led1, led0) <= temp;
    end if;
  end process;
end synth;
