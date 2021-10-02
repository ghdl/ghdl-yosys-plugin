library ieee;
use ieee.std_logic_1164.all;

entity repro3 is
  port(
   clk : in std_logic;
   inp : std_logic;
   module_to_clk_cross : out std_ulogic);
end;

architecture arch of repro3 is
  type variables_t is record
    iftrue : std_logic_vector(3 downto 0);
    inp : std_logic;
    return_output : std_logic_vector(3 downto 0);
  end record;
begin
  process (clk) is
    variable read_pipe : variables_t;
    variable write_pipe : variables_t;
  begin
    write_pipe := read_pipe;
    write_pipe.inp := inp;
    read_pipe := write_pipe;
  end process;
end arch;
