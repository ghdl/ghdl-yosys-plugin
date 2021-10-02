library ieee;
use ieee.std_logic_1164.all;

entity repro4 is
  port(
    clk : in std_logic;
    iftrue : out std_logic);
end;

architecture arch of repro4 is
  type variables_t is record
    iftrue : std_logic;
    return_output : std_logic;
  end record;
begin
  process (clk) is
    variable read_pipe : variables_t;
    variable write_pipe : variables_t;
  begin
    write_pipe := read_pipe;
    iftrue <= write_pipe.iftrue;
    read_pipe := write_pipe;
  end process;
end arch;
