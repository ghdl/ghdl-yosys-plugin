library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity variable_srl is
  port (
    clk : in std_logic;
    ce  : in std_logic;
    d   : in std_logic;
    a   : in std_logic_vector(3 downto 0);
    q   : out std_logic
  );
end entity;

architecture rtl of variable_srl is
  signal sreg : std_logic_vector(15 downto 0) := (others => '0');
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if ce = '1' then
        sreg <= sreg(14 downto 0) & d;
      end if;
    end if;
  end process;

  q <= sreg(to_integer(unsigned(a)));
end architecture;
