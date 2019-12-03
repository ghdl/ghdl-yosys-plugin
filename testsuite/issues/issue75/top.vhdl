library ieee;
use ieee.std_logic_1164.ALL;

entity child is
  port (
    CLK: in std_logic;
    I: in std_logic;
    O: out std_logic
  );
end entity child;

architecture rtl of child is
  signal Ialias: std_logic;
begin
  process (CLK)
  begin
    if rising_edge(CLK) then
      O <= Ialias;
    end if;
  end process;
  Ialias <= I;
end architecture rtl;


library ieee;
use ieee.std_logic_1164.ALL;

entity top is
  port (
    CLK: in std_logic;
    I: in std_logic;
    O: out std_logic
  );
end entity top;

architecture rtl of top is
  component child is
    port (
      CLK: in std_logic;
      I: in std_logic;
      O: out std_logic
    );
  end component child;
begin
  inst : child port map(CLK, I, O);
end architecture rtl;
