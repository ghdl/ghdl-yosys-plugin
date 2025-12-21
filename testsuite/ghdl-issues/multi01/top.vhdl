library ieee;
use ieee.std_logic_1164.all;

entity top is
  generic (
    WIDTH : integer := 4
  );
  port (
    a : in  std_logic_vector(WIDTH-1 downto 0);
    b : in  std_logic_vector(WIDTH-1 downto 0);
    y : out std_logic_vector(WIDTH-1 downto 0)
  );
end entity top;

architecture rtl of top is
begin

  u_xor : entity work.xor_generic
    generic map (
      WIDTH => WIDTH
    )
    port map (
      a => a,
      b => b,
      y => y
    );

end architecture rtl;
