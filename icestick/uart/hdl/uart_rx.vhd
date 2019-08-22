library ieee;
  use ieee.std_logic_1164.all;

entity uart_rx is
  generic (
    C_BITS           : integer := 8;
    C_CYCLES_PER_BIT : integer := 104
  );
  port (
    isl_clk    : in std_logic;
    isl_data_n : in std_logic;
    oslv_data  : out std_logic_vector(C_BITS-1 downto 0);
    osl_valid  : out std_logic
  );
end entity uart_rx;

architecture rtl of uart_rx is
  signal int_cycle_cnt : integer range 0 to C_CYCLES_PER_BIT-1 := 0;
  signal int_bit_cnt : integer range 0 to C_BITS+1 := 0;

  signal slv_data : std_logic_vector(C_BITS-1 downto 0) := (others => '0');
  signal sl_valid : std_logic := '0';

  type t_state is (IDLE, INIT, RECEIVE);
  signal state : t_state;

begin
  process(isl_clk)
  begin
    if rising_edge(isl_clk) then
      case state is
        when IDLE =>
          sl_valid <= '0';
          if isl_data_n = '0' then
            -- wait for the start bit
            state <= INIT;
          end if;
        
        when INIT =>
          int_cycle_cnt <= C_CYCLES_PER_BIT / 2;
          int_bit_cnt <= 0;
          state <= RECEIVE;

        when RECEIVE =>
          if int_bit_cnt < C_BITS+1 then
            if int_cycle_cnt < C_CYCLES_PER_BIT-1 then
              int_cycle_cnt <= int_cycle_cnt+1;
            else
              -- receive data bits
              int_cycle_cnt <= 0;
              int_bit_cnt <= int_bit_cnt+1;
              slv_data <= not isl_data_n & slv_data(slv_data'LEFT downto 1); -- low active
            end if;
          elsif isl_data_n = '1' then
            -- wait for the stop bit
            sl_valid <= '1';
            state <= IDLE;
          end if;

      end case;
    end if;
  end process;

  oslv_data <= slv_data;
  osl_valid <= sl_valid;
end architecture rtl;
