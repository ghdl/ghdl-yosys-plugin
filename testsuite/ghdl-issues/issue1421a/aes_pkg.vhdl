
library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

package aes_pkg is

  type t_usig_1d is array(natural range <>) of unsigned(7 downto 0);

  type t_usig_2d is array(natural range <>, natural range <>) of unsigned(7 downto 0);

  constant C_STATE_ROWS : integer := 2;
  constant C_STATE_COLS : integer := 2;

  subtype st_word is t_usig_1d(0 to C_STATE_COLS - 1);
  subtype st_state is t_usig_2d(0 to C_STATE_ROWS - 1, 0 to C_STATE_COLS - 1);
  subtype st_sbox is t_usig_1d(0 to 255);

  type t_key is array(natural range <>) of st_word;

  function mix_columns (a_in : st_state) return st_state;

end package aes_pkg;

package body aes_pkg is

  -- FIPS 197, 5.1.3 MixColumns() Transformation

  function mix_columns (a_in : st_state) return st_state is
    variable a_out : st_state;
  begin
    for col in 0 to C_STATE_COLS - 1 loop
      a_out(0, col) := a_in(0, col) xor
                       a_in(1, col);
      a_out(1, col) := a_in(0, col) xor
                       a_in(1, col);
    end loop;
    return a_out;
  end mix_columns;
end package body;
