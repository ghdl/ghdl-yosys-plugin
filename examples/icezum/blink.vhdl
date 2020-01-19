library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity blink is
  port (
    clk : in std_logic;
    led0, led1, led2, led3, led4, led5, led6, led7 : out std_logic
  );
end blink;

architecture synth of blink is
  signal blink: std_logic;
begin
  process (clk)
    variable cnt : unsigned (23 downto 0);  -- 3_000_000 requires 24 bits
  begin
    if rising_edge(clk) then
      if cnt = 2_999_999 then
        cnt := x"000000";
        blink <= not blink;
      else
        cnt := cnt + 1;
      end if;
    end if;
  end process;
  led0 <= blink;
  led1 <= blink;
  led2 <= blink;
  led3 <= blink;
  led4 <= blink;
  led5 <= blink;
  led6 <= blink;
  led7 <= blink;
end synth;
