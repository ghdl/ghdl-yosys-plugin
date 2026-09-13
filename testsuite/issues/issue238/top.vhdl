library ieee;
use ieee.std_logic_1164.all;

entity sub is
  port (
    a : inout std_logic := 'Z';
    b : out std_logic
  );
end entity sub;

architecture rtl of sub is
begin
  b <= a;
end architecture;

----

library ieee;
use ieee.std_logic_1164.all;

entity top is
  port (
    a : inout std_logic := 'Z';
    b : out std_logic;
    c : inout std_logic := 'Z';
    d : out std_logic
  );
end entity top;

architecture rtl of top is
begin
  sub_inst : entity work.sub
    port map
    (
      a => a,
      b => b
    );
  d <= c;
end architecture;
