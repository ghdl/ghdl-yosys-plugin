library ieee;
use ieee.std_logic_1164.all;

entity xor_generic is
  generic (
    WIDTH : integer := 8
  );
  port (
    a : in  std_logic_vector(WIDTH-1 downto 0);
    b : in  std_logic_vector(WIDTH-1 downto 0);
    y : out std_logic_vector(WIDTH-1 downto 0)
  );
end entity xor_generic;

architecture rtl of xor_generic is
begin
  y <= a xor b;
end architecture rtl;
