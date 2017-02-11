library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity blink is
  port (clk : in std_logic;
        led0, led1, led2, led3, led4, led5, led6, led7 : out std_logic);
end blink;

architecture synth of blink is
  signal clk_4hz: std_logic;
begin
  process (clk)
    --  3_000_000 is 0x2dc6c0
    variable counter : unsigned (23 downto 0);
  begin
    if rising_edge(clk) then
      if counter = 2_999_999 then
        counter := x"000000";
        clk_4hz <= not clk_4hz;
      else
        counter := counter + 1;
      end if;
    end if;
  end process;

  led0 <= clk_4hz;
  led1 <= clk_4hz;
  led2 <= clk_4hz;
  led3 <= clk_4hz;
  led4 <= clk_4hz;
  led5 <= clk_4hz;
  led6 <= clk_4hz;
  led7 <= clk_4hz;
end synth;
