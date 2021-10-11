library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fpu is
    port (
        clk         : in std_ulogic;
        addr        : in std_ulogic_vector(1 downto 0);
        inverse_est : out std_ulogic_vector(17 downto 0)
        );
end entity fpu;

architecture behaviour of fpu is
    type lookup_table is array(0 to 3) of std_ulogic_vector(17 downto 0);

    constant inverse_table : lookup_table := (
        18x"3fc01", 18x"3f411", 18x"3ec31", 18x"3e460"
        );
begin
    lut_access: process(clk)
    begin
        if rising_edge(clk) then
            inverse_est <= inverse_table(to_integer(unsigned(addr)));
        end if;
    end process;

end architecture behaviour;
