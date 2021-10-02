library ieee;
use ieee.std_logic_1164.all;

entity MUX_uint4 is
  port(
    iftrue : in std_logic_vector(3 downto 0);
    return_output : out std_logic_vector(3 downto 0));
end;
architecture arch of MUX_uint4 is
begin
  return_output <= iftrue;
end arch;

library ieee;
use ieee.std_logic_1164.all;

entity repro is
  port(
   clk : in std_logic;
   module_to_clk_cross : out std_ulogic);
end;

architecture arch of repro is
  type variables_t is record
    iftrue : std_logic_vector(3 downto 0);
    return_output : std_logic_vector(3 downto 0);
  end record;

  signal iftrue : std_logic_vector(3 downto 0);
  signal return_output : std_logic_vector(3 downto 0);
begin
  c3_8e8a : entity work.MUX_uint4 port map (iftrue, return_output);

  process (clk) is
    variable read_pipe : variables_t;
    variable write_pipe : variables_t;
  begin
    write_pipe := read_pipe;
    iftrue <= write_pipe.iftrue;
  --  write_pipe.return_output := return_output;
    read_pipe := write_pipe;
  end process;
end arch;
