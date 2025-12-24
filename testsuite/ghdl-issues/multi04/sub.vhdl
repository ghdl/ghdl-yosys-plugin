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
  gen_1: if width = 1 generate
    y(0) <= a(0) xor b(0);
  end generate;
  gen_m: if width > 1 generate
    constant half : natural := width / 2;
  begin
    inst_lo: entity work.xor_generic
      generic map (width => half)
      port map (a(half - 1 downto 0), b(half - 1 downto 0),
                y(half - 1 downto 0));
    inst_hi: entity work.xor_generic
      generic map (width => width - half)
      port map (a(width - 1 downto half), b(width - 1 downto half),
                y(width - 1 downto half));
  end generate;
end architecture rtl;
