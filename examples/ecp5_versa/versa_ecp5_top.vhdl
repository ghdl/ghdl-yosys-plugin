--
-- Versa ECP5(G) top level module
--
--
-- 1/2017  Martin Strubel <hackfin@section5.ch>
--
-- Taken from MaSoCist and stripped down for the example.
-- Functionality:

-- * Blinks the first orange LED every second
-- * Loops back the UART (fixed at 115200 bps) through a FIFO and
--   turns lower cap alpha characters into upper case.


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
	use work.system_map.all;

entity versa_ecp5_top is
    generic(
        CLK_FREQUENCY : positive := 25000000
    );
	port (
		twi_scl  : inout std_logic;
		twi_sda  : inout std_logic;

		rxd_uart    : in std_logic;	  -- FT2232 -> CPU
		txd_uart    : out std_logic;  -- CPU    -> FT2232

		oled         : out  std_logic_vector(7 downto 0);
		seg          : out  std_logic_vector(13 downto 0);
		segdp        : out  std_logic;
		dip_sw       : in   std_logic_vector(7 downto 0);

		reset_n      : in   std_logic;
		clk_in       : in   std_ulogic

	);
end entity versa_ecp5_top;


architecture behaviour of versa_ecp5_top is

	signal mclk           : std_logic;
	signal mclk_locked    : std_logic;

	-- Pixel clock:
	signal pclk           : std_logic;

	signal comb_reset     : std_logic;

	constant f_half : integer := CLK_FREQUENCY / 2;
	signal reset_delay    : unsigned(3 downto 0);
	signal led            : unsigned(7 downto 0);
    signal counter : integer range 0 to f_half;
    signal toggle_led : std_ulogic := '0';

	-- Uart signals:
	signal uart_ctrl      : uart_WritePort;
	signal uart_stat      : uart_ReadPort;

    signal uart_idle      : std_ulogic := '0';
    signal rxready_d      : std_ulogic := '0';
	signal uart_data      : unsigned(7 downto 0);

 
begin

	comb_reset <= (not reset_n) or (not mclk_locked);

	seg <= (others => '1'); -- low active
	segdp <= '1'; -- low active

	process(mclk)
    begin
        if rising_edge(mclk) then
            counter <= counter + 1;
            if counter = f_half then
                toggle_led <= not toggle_led;
                counter <= 0;
            end if;
        end if;
    end process;


clk_pll1: entity work.pll_mac
    port map (
        CLKI    =>  clk_in,
        CLKOP   =>  open,
        CLKOS   =>  mclk, -- 25 Mhz
        CLKOS2  =>  open,
        CLKOS3  =>  pclk,
        LOCK    =>  mclk_locked
	);

	-- Static config:
	uart_ctrl.uart_clkdiv <= to_unsigned(CLK_FREQUENCY / 16 / 115200, 10);
	uart_ctrl.rx_irq_enable <= '0';
	uart_ctrl.uart_reset <= comb_reset;

-- UART loopback logic:
	process (mclk)
	begin
		if rising_edge(mclk) then
			uart_ctrl.select_uart_txr <= '0'; -- default 0
			uart_ctrl.select_uart_rxr <= '0'; -- default 0
			rxready_d <= uart_stat.rxready;
			if uart_idle = '1' then
				uart_idle <= '0';
			else
				if rxready_d = '1' then
					-- Modify the data a bit:
					if uart_data > x"40" and uart_data < x"ff" then
						uart_ctrl.uart_txr <= uart_data and "01011111";
					else
						uart_ctrl.uart_txr <= uart_data;
					end if;
					uart_ctrl.select_uart_txr <= '1'; -- signal a write
				end if;
				if uart_stat.rxready = '1' then
					uart_data <= uart_stat.rxdata; -- Read data
					uart_ctrl.select_uart_rxr <= '1'; -- signal a read
					uart_idle <= '1'; -- Wait state
				end if;
			end if;
		end if;
	end process;

uart_inst:
	entity work.uart_core
	port map (
		tx        => txd_uart,
		rx        => rxd_uart,
		rxirq     => open,
		ctrl      => uart_ctrl,
		stat      => uart_stat,
		clk       => mclk
	);

    led(0) <= toggle_led;
    led(1) <= '0';
    led(2) <= '1';
	led(3) <= '0';
	led(4) <= '0';
	led(5) <= not rxd_uart;
	led(6) <= '0';
	led(7) <= uart_stat.rxovr;

	-- Note LED are low active
	oled <= not std_logic_vector(led);

	twi_sda <= 'H';
	twi_scl <= 'H';


	-- txd_uart   <= rxd_uart;
	

end behaviour;
