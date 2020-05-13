library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity conversion_to_RGB is
    port ( clk      : in std_Logic;
           in_V     : in std_logic_vector(11 downto 0);
           in_W     : in std_logic_vector(11 downto 0);

           out_G     : out std_logic_vector(11 downto 0);
           out_R     : out std_logic_vector(11 downto 0));
end entity;

architecture Behavioral of conversion_to_RGB is
begin
clk_proc: process(clk)
   begin
      if rising_edge(clk) then
	out_G <= in_V;
	out_R <= in_W;
      end if;
   end process;
end architecture;
