library ieee;
use ieee.std_logic_1164.all;

entity MUX_uint4 is
  port(
    cond : in std_logic_vector(0 downto 0);
    iftrue : in std_logic_vector(3 downto 0);
    iffalse : in std_logic_vector(3 downto 0);
    return_output : out std_logic_vector(3 downto 0));
end;
architecture arch of MUX_uint4 is
begin
  return_output <= iftrue when cond = "1" else iffalse;
end arch;

library ieee;
use ieee.std_logic_1164.all;

entity repro1 is
  port(
   clk : in std_logic;
   CLOCK_ENABLE : in std_logic_vector(0 downto 0);
   module_to_clk_cross : out std_ulogic);
end;

architecture arch of repro1 is
  type variables_t is record
    c3_8e8a_cond : std_logic_vector(0 downto 0);
    c3_8e8a_iffalse : std_logic_vector(3 downto 0);
    c3_8e8a_iftrue : std_logic_vector(3 downto 0);
    c3_8e8a_return_output : std_logic_vector(3 downto 0);
  end record;

  signal c3_8e8a_cond : std_logic_vector(0 downto 0);
  signal c3_8e8a_iftrue : std_logic_vector(3 downto 0);
  signal c3_8e8a_iffalse : std_logic_vector(3 downto 0);
  signal c3_8e8a_return_output : std_logic_vector(3 downto 0);
begin
  c3_8e8a : entity work.MUX_uint4 port map (
    c3_8e8a_cond,
    c3_8e8a_iftrue,
    c3_8e8a_iffalse,
    c3_8e8a_return_output);

  process (CLOCK_ENABLE) is
    variable read_pipe : variables_t;
    variable write_pipe : variables_t;
  begin
    write_pipe := read_pipe;
    c3_8e8a_cond <= write_pipe.c3_8e8a_cond;
    c3_8e8a_iftrue <= write_pipe.c3_8e8a_iftrue;
    c3_8e8a_iffalse <= write_pipe.c3_8e8a_iffalse;
    write_pipe.c3_8e8a_return_output := c3_8e8a_return_output;
    read_pipe := write_pipe;
  end process;
end arch;
