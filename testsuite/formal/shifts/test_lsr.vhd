library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity test_lsr is
  port (
    -- globals
    reset : in  std_logic;
    clk   : in  std_logic;
    -- inputs
    unsig : in  unsigned(7 downto 0);
    -- outputs
    lsr   : out unsigned(7 downto 0)
  );
end entity test_lsr;


architecture rtl of test_lsr is

  signal index : natural;

begin

  process (clk) is
  begin
    if rising_edge(clk) then
      if reset = '1' then
        index <= 0;
        lsr  <= x"00";
      else
        lsr <= shift_right(unsig, index);
        if index < natural'high then
          index <= index + 1;
        end if;
      end if;
    end if;
  end process;

  Formal : block is

    signal uns_d : unsigned(7 downto 0);

  begin

    default clock is rising_edge(clk);
    restrict {reset[*1]; not reset[+]}[*1];

    -- Register inputs
    -- Workaround for missing prev() PSL function
    process (clk) is
    begin
      if rising_edge(clk) then
        uns_d <= unsig;
      end if;
    end process;

    assert reset -> next lsr = 0;
    -- Workaround for missing IIR_PREDEFINED_IEEE_NUMERIC_STD_EQ_SGN_INT
    -- Comparing with hex literals like x"00" in PSL code generates an error:
    -- no declaration for ""

    shift_right_0 : assert always not reset and index = 0 -> next lsr = uns_d;
    shift_right_1 : assert always not reset and index = 1 -> next lsr = '0' & uns_d(7 downto 1);
    shift_right_2 : assert always not reset and index = 2 -> next lsr = "00" & uns_d(7 downto 2);
    shift_right_3 : assert always not reset and index = 3 -> next lsr = "000" & uns_d(7 downto 3);
    shift_right_4 : assert always not reset and index = 4 -> next lsr = "0000" & uns_d(7 downto 4);
    shift_right_5 : assert always not reset and index = 5 -> next lsr = "00000" & uns_d(7 downto 5);
    shift_right_6 : assert always not reset and index = 6 -> next lsr = "000000" & uns_d(7 downto 6);
    shift_right_7 : assert always not reset and index = 7 -> next lsr = "0000000" & uns_d(7);
    shift_right_8 : assert always not reset and index >= 8 -> next lsr = 0;

  end block Formal;

end architecture rtl;
