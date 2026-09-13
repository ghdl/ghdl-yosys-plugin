library ieee;
use ieee.std_logic_1164.all;

entity sub2 is
  port (
    a : inout std_logic := 'Z';
    b : out std_logic
  );
end entity sub2;

architecture rtl of sub2 is
begin
  b <= a;
end architecture;

----

library ieee;
use ieee.std_logic_1164.all;

entity top2 is
  port (
    a : inout std_logic_vector(1 downto 0) := "ZZ";
    b : out std_logic_vector(1 downto 0);
    c : inout std_logic_vector(1 downto 0) := "ZZ";
    d : out std_logic
  );
end entity top2;

architecture rtl of top2 is
begin
  sub_inst0 : entity work.sub2
    port map
    (
      a => a(0),
      b => b(0)
    );
--  sub_inst1 : entity work.sub2
--    port map
--    (
--      a => a(1),
--      b => b(1)
--    );
  d <= c(0);
end architecture;
