-- cipher module, as described in: "FIPS 197, 5.1 Cipher"

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library aes_lib;
  use aes_lib.aes_pkg.all;

entity cipher is
  generic (
    G_KEY_WORDS : integer := 4
  );
  port (
    isl_clk   : in    std_logic;
    isl_valid : in    std_logic;
    ia_data   : in    st_state;
    ia_key    : in    t_key(0 to G_KEY_WORDS - 1);
    oa_data   : out   st_state;
    osl_valid : out   std_logic
  );
end entity cipher;

architecture rtl of cipher is

  -- states
  signal slv_stage     : std_logic_vector(1 to 2) := (others => '0');
  signal sl_next_round : std_logic := '0';

  -- data container
  -- data format in key expansion: words are rows
  -- data format in cipher: words are columns
  -- conversion: transpose matrix
  signal a_data_in    : st_state;
  signal a_data_added : st_state;
  signal a_data_srows : st_state;

  -- keys
  signal a_round_keys  : st_state;
  signal int_round_cnt : integer range 0 to 13 := 0;

begin

  sl_next_round <= slv_stage(2);

  proc_key_expansion : process (isl_clk) is

    variable v_new_col    : integer range 0 to C_STATE_COLS - 1;
    variable v_data_sbox  : st_state;
    variable v_data_mcols : st_state;

  begin

    if (rising_edge(isl_clk)) then
      slv_stage <= (isl_valid or sl_next_round) & slv_stage(1);

      -- substitute bytes and shift rows
      if (slv_stage(1) = '1') then
        for row in 0 to C_STATE_ROWS - 1 loop
          for col in 0 to 0 loop --C_STATE_COLS - 1 loop
            -- substitute bytes
--            v_data_sbox(row, col) := C_SBOX(to_integer(a_data_added(row, col)));
            v_data_sbox(row, col) := a_data_added(row, col);

            -- shift rows
            -- avoid modulo by using unsigned overflow
            v_new_col := to_integer(to_unsigned(col, 1) - row);
            a_data_srows(row, v_new_col) <= v_data_sbox(row, col);
          end loop;
        end loop;
      end if;

      -- mix columns and add key
      if (slv_stage(2) = '1') then
        a_data_added <= mix_columns(a_data_srows);
      end if;
    end if;

  end process proc_key_expansion;

  oa_data   <= a_data_added;
  osl_valid <= '0';

end architecture rtl;
