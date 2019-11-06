library ieee;
use ieee.std_logic_1164.all;

entity test is
  port (
    Reset_n_i    : in  std_logic;
    Clk_i        : in  std_logic;
    Wen_i        : in  std_logic;
    Addr_i       : in  natural range 0 to 2**8-1;
    Din_i        : in  std_logic_vector(7 downto 0);
    Dout_o       : out std_logic_vector(7 downto 0)
  );
end entity test;

architecture rtl of test is

  type t_register is array(0 to 7) of std_logic_vector(7 downto 0);
  signal s_register : t_register;

begin

  Dout_o <= s_register(Addr_i);

  WriteP : process (Clk_i, Reset_n_i) is
  begin
    if Reset_n_i = '0' then
      s_register <= (others => (others => '0'));
    elsif rising_edge(Clk_i) then
      if Wen_i = '1' then
        s_register(Addr_i) <= Din_i;
      end if;
    end if;
  end process WriteP;

end architecture rtl;
