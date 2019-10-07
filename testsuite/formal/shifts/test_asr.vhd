library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity test_asr is
  port (
    -- globals
    reset : in  std_logic;
    clk   : in  std_logic;
    -- inputs
    sig   : in  signed(7 downto 0);
    -- outputs
    asr   : out signed(7 downto 0)
  );
end entity test_asr;


architecture rtl of test_asr is

  signal index : natural;

begin

  process (clk) is
  begin
    if rising_edge(clk) then
      if reset = '1' then
        index <= 0;
        asr   <= x"00";
      else
        asr <= shift_right(sig, index);
        if index < natural'high then
          index <= index + 1;
        end if;
      end if;
    end if;
  end process;

  Formal : block is

    signal sig_d   : signed(7 downto 0);
    signal sig_d_7 : signed(7 downto 0);

  begin

    default clock is rising_edge(clk);
    restrict {reset[*1]; not reset[+]}[*1];

    -- Register inputs
    -- Workaround for missing prev() PSL function
    process (clk) is
    begin
      if rising_edge(clk) then
        sig_d <= sig;
      end if;
    end process;

    -- helper signal for sign extension
    sig_d_7 <= (others => sig_d(7));

    assert reset -> next asr = "00000000";
    -- Workaround for missing IIR_PREDEFINED_IEEE_NUMERIC_STD_EQ_SGN_INT
    -- Comparing with hex literals like x"00" in PSL code generates an error:
    -- no declaration for ""

    shift_aright_0 : assert always not reset and index = 0 -> next asr = sig_d;
    shift_aright_1 : assert always not reset and index = 1 -> next asr = sig_d_7(7) & sig_d(7 downto 1);
    shift_aright_2 : assert always not reset and index = 2 -> next asr = sig_d_7(7 downto 6) & sig_d(7 downto 2);
    shift_aright_3 : assert always not reset and index = 3 -> next asr = sig_d_7(7 downto 5) & sig_d(7 downto 3);
    shift_aright_4 : assert always not reset and index = 4 -> next asr = sig_d_7(7 downto 4) & sig_d(7 downto 4);
    shift_aright_5 : assert always not reset and index = 5 -> next asr = sig_d_7(7 downto 3) & sig_d(7 downto 5);
    shift_aright_6 : assert always not reset and index = 6 -> next asr = sig_d_7(7 downto 2) & sig_d(7 downto 6);
    shift_aright_7 : assert always not reset and index = 7 -> next asr = sig_d_7(7 downto 1) & sig_d(7);
    shift_aright_8 : assert always not reset and index >= 8 -> next asr = sig_d_7;

  end block Formal;

end architecture rtl;
