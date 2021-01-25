library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.numeric_std.ALL;

entity exp is
  port (
    clk : in    std_logic
  );
end entity exp;

architecture behav of exp is

  signal ver_clk : std_logic;
  signal count : integer := 0;

  attribute gclk : boolean;
  attribute gclk of ver_clk : signal is true;

begin

  default Clock is rising_edge(clk);

  process (ver_clk)
  begin
    if rising_edge(ver_clk) then
      count <= count + 1;
    end if;
  end process;

  assert always next count = prev(count) + 1;

end architecture behav;
