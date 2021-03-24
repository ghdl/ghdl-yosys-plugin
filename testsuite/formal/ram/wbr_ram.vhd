library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity wbr_ram is
   port (
      clk_i     : in  std_logic;
      addr_i    : in  std_logic_vector(7 downto 0);
      wr_data_i : in  std_logic_vector(15 downto 0);
      wr_en_i   : in  std_logic;
      rd_data_o : out std_logic_vector(15 downto 0)
   );
end entity wbr_ram;

architecture synthesis of wbr_ram is

   type mem_t is array (0 to 255) of std_logic_vector(15 downto 0);

begin

   p_write_first : process (clk_i)
      variable mem : mem_t := (others => (others => '0'));
   begin
      if rising_edge(clk_i) then
         if wr_en_i = '1' then
            mem(to_integer(unsigned(addr_i))) := wr_data_i;
         end if;

         rd_data_o <= mem(to_integer(unsigned(addr_i)));
      end if;
   end process p_write_first;

  -- All is sensitive to rising edge of clk
  default clock is rising_edge(clk_i);

  f_wbr : assert always {wr_en_i = '1'} |=> {rd_data_o = prev(wr_data_i)};

end architecture synthesis;

