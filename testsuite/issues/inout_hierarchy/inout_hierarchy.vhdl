library ieee;
use ieee.std_logic_1164.all;

entity inout_child is
  port (
    pad   : inout std_logic_vector(3 downto 0);
    drive : in std_logic_vector(3 downto 0);
    oe    : in std_logic_vector(3 downto 0);
    sense : out std_logic_vector(3 downto 0)
  );
end entity;

architecture rtl of inout_child is
begin
  gen_pads : for i in pad'range generate
    pad(i) <= drive(i) when oe(i) = '1' else 'Z';
  end generate;
  sense <= pad;
end architecture;

library ieee;
use ieee.std_logic_1164.all;

entity inout_top is
  port (
    pads  : inout std_logic_vector(3 downto 0);
    drive : in std_logic_vector(3 downto 0);
    oe    : in std_logic_vector(3 downto 0);
    sense : out std_logic_vector(3 downto 0)
  );
end entity;

architecture rtl of inout_top is
begin
  child : entity work.inout_child
    port map (
      pad => pads,
      drive => drive,
      oe => oe,
      sense => sense
    );
end architecture;
