library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity test2 is
    port (
        clk  : in std_ulogic;
        addr : in std_ulogic_vector(4 downto 0);
        data : out std_ulogic_vector(2 downto 0)
    );
end entity test2;

architecture rtl of test2 is
    type result_t is array(integer range 0 to 15) of std_ulogic_vector(2 downto 0);

    constant result_select : result_t := (
        0      => "001",
        1      => "001",
        2      => "001",
        3      => "001",
        4      => "001",
        5      => "001",
        6      => "001",
        7      => "001",
        others => "000"
        );
begin

    --lookup_0: process(all)
    --begin
        --data <= result_select(to_integer(unsigned(addr)));
    --end process;

    lookup_0: process(clk)
    begin
        if rising_edge(clk) then
            data <= result_select(to_integer(unsigned(addr)));
        end if;
    end process;
end;

