library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity test is
    port(
        clk          : in std_logic;

        read1_reg     : in std_ulogic_vector(4 downto 0);
        read1_data    : out std_ulogic_vector(63 downto 0);

        read2_reg     : in std_ulogic_vector(4 downto 0);
        read2_data    : out std_ulogic_vector(63 downto 0);

        read3_reg     : in std_ulogic_vector(4 downto 0);
        read3_data    : out std_ulogic_vector(63 downto 0);

        write_enable : in std_ulogic;
        write_reg    : in std_ulogic_vector(4 downto 0);
        write_data   : in std_ulogic_vector(63 downto 0)
        );
end entity test;

architecture behaviour of test is
    type regfile is array(0 to 31) of std_ulogic_vector(63 downto 0);
    signal registers : regfile;
begin
    register_write_0: process(clk)
    begin
        if rising_edge(clk) then
            if write_enable = '1' then
                registers(to_integer(unsigned(write_reg))) <= write_data;
            end if;
        end if;
    end process register_write_0;

    register_read_0: process(all)
    begin
        read1_data <= registers(to_integer(unsigned(read1_reg)));
        read2_data <= registers(to_integer(unsigned(read2_reg)));
        read3_data <= registers(to_integer(unsigned(read3_reg)));
    end process register_read_0;
end architecture behaviour;
