library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity test_lsl is
  port (
    -- globals
    reset : in  std_logic;
    clk   : in  std_logic;
    -- inputs
    unsig : in  unsigned(7 downto 0);
    sig   : in  signed(7 downto 0);
    -- outputs
    lslu   : out unsigned(7 downto 0);
    lsls   : out signed(7 downto 0)
  );
end entity test_lsl;


architecture rtl of test_lsl is

  signal index : natural;

begin

  process (clk) is
  begin
    if rising_edge(clk) then
      if reset = '1' then
        index <= 0;
        lslu  <= x"00";
        lsls  <= x"00";
      else
        lslu <= shift_left(unsig, index);
        lsls <= shift_left(sig, index);
        if index < natural'high then
          index <= index + 1;
        end if;
      end if;
    end if;
  end process;

  Formal : block is

    signal uns_d : unsigned(7 downto 0);
    signal sig_d : signed(7 downto 0);

  begin

    default clock is rising_edge(clk);
    restrict {reset[*1]; not reset[+]}[*1];

    -- Register inputs
    -- Workaround for missing prev() PSL function
    process (clk) is
    begin
      if rising_edge(clk) then
        uns_d <= unsig;
        sig_d <= sig;
      end if;
    end process;

    assert reset -> next lslu = 0;
    assert reset -> next lsls = "00000000";
    -- Workaround for missing IIR_PREDEFINED_IEEE_NUMERIC_STD_EQ_SGN_INT
    -- Comparing with hex literals like x"00" in PSL code generates an error:
    -- no declaration for ""

    shift_left_uns_0 : assert always not reset and index = 0 -> next lslu = uns_d;
    shift_left_uns_1 : assert always not reset and index = 1 -> next lslu = uns_d(6 downto 0) & '0';
    shift_left_uns_2 : assert always not reset and index = 2 -> next lslu = uns_d(5 downto 0) & "00";
    shift_left_uns_3 : assert always not reset and index = 3 -> next lslu = uns_d(4 downto 0) & "000";
    shift_left_uns_4 : assert always not reset and index = 4 -> next lslu = uns_d(3 downto 0) & "0000";
    shift_left_uns_5 : assert always not reset and index = 5 -> next lslu = uns_d(2 downto 0) & "00000";
    shift_left_uns_6 : assert always not reset and index = 6 -> next lslu = uns_d(1 downto 0) & "000000";
    shift_left_uns_7 : assert always not reset and index = 7 -> next lslu = uns_d(0) & "0000000";
    shift_left_uns_8 : assert always not reset and index >= 8 -> next lslu = 0;

    shift_left_sgn_0 : assert always not reset and index = 0 -> next lsls = sig_d;
    shift_left_sgn_1 : assert always not reset and index = 1 -> next lsls = sig_d(6 downto 0) & '0';
    shift_left_sgn_2 : assert always not reset and index = 2 -> next lsls = sig_d(5 downto 0) & "00";
    shift_left_sgn_3 : assert always not reset and index = 3 -> next lsls = sig_d(4 downto 0) & "000";
    shift_left_sgn_4 : assert always not reset and index = 4 -> next lsls = sig_d(3 downto 0) & "0000";
    shift_left_sgn_5 : assert always not reset and index = 5 -> next lsls = sig_d(2 downto 0) & "00000";
    shift_left_sgn_6 : assert always not reset and index = 6 -> next lsls = sig_d(1 downto 0) & "000000";
    shift_left_sgn_7 : assert always not reset and index = 7 -> next lsls = sig_d(0) & "0000000";
    shift_left_sgn_8 : assert always not reset and index >= 8 -> next lsls = "00000000";

  end block Formal;

end architecture rtl;
