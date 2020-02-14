-- UART RX implementation
--
-- (c) 06/2008, Martin Strubel <strubel@section5.ch>

-- This module implements a standard UART receive channel.
-- The clock divider has to be chosen such that the master clock
-- divided by k = (2 * (div + 1)) is the 16 fold of the desired baud
-- rate.

-- On reception of a start bit, the lock counter is starting and the
-- signal is sampled at the position of each lock marker which is at
-- 'count' = 8 by default.

-- Once a byte has arrived, it has to be read immediately by the
-- client (FIFO assumed). Valid data must be clocked on rising edge of
-- the 'strobe' pin from the 'data' bus.

-- This is a very primitive implementation:
-- * No Parity and other checks
-- * No debouncing. Must be done on top level input.

library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;      -- for TO_UNSIGNED


entity UARTrx is
	generic (
		CLKDIV2 : positive := 3    -- power of 2 of (clkdiv)
	);
	port (
		d_bitcount       :  out unsigned(2 downto 0);

		rx               : in std_logic;   -- RX UART
		err_frame        : out std_logic;
		-- Data
		data             : out unsigned(7 downto 0);
		strobe           : out std_logic;  -- Data valid strobe pulse
		reset            : in std_logic;   -- Reset pin, LOW active
		clk16en          : in std_logic;   -- UART clock enable
		clk            : in std_logic    -- UART clock x 16
	);

end UARTrx;

architecture behaviour of UARTrx is
	-- State machine states:
	-- IDLE: Waiting for start bit
	-- START: Getting start bit
	-- SHIFT: Shifting data
	-- STOP: Getting stop bit ( No longer used, identical with S_IDLE )

	type uart_state_t is (S_IDLE, S_START, S_SHIFT, S_STOP);

	signal state        :  uart_state_t := S_IDLE;
	signal rxd          :  std_logic;
	signal frame_err    :  std_logic    := '0';    -- Frame Error flag
	signal rxtrigger    :  std_logic;
	-- signal start        :  std_logic    := '0';

	signal strobeq      :  std_logic;
	signal strobe_i     :  std_logic;

	signal bitcount     :  unsigned(2 downto 0) := "000"; -- Bit counter
	-- This is the clk counter that is used to synchronize to the
	-- middle of a data bit signal
	signal count   :  unsigned(CLKDIV2 downto 0) := (others => '0');
	signal is_count_begin  : std_logic; -- When count == 0
	signal is_count_mid    : std_logic; -- When count == 8
	-- Shift register:
	signal dsr          :  unsigned(7 downto 0) := x"00";

begin

	-- Detect RX start bit (synchronous to clk):
rx_posedge:
	process (clk)
	begin
		if rising_edge(clk) then
			if clk16en = '1' then
				rxd <= rx;
				rxtrigger <= rxd and (not rx);
			end if;
		end if;
	end process;

	-- This signal is:
	-- HIGH on falling edge
	-- LOW on rising edge, LOW when idle

	-- It is not latched, thus it can be very short.


generate_rxclk_en:
	process (clk)
	begin
		if rising_edge(clk) then
			if clk16en = '1' then
				case state is
					when S_IDLE  => count <= (others => '0');
					when others => count <= count + 1;
				end case;
			end if;
		end if;
	end process;

	is_count_begin <= '1' when count = "1111" else '0';
	is_count_mid <= '1'   when count = "0111" else '0';
	
state_decode:
	process (clk)
	begin
		if rising_edge(clk) then
			if reset = '1' then
				state <= S_IDLE;
			elsif clk16en = '1' then
				case state is
				when S_STOP | S_IDLE =>
					if rxtrigger = '1' then
						state <= S_START;
					else
						state <= S_IDLE;
					end if;
				when S_START =>
					if is_count_begin = '1' then
						state <= S_SHIFT;
					end if;
				when S_SHIFT =>
					if is_count_begin = '1' and bitcount = "111" then
						state <= S_STOP;
					end if;
				when others =>
					state <= S_IDLE;
				end case;
			end if;
		end if;
	end process;

shift:
	process (clk)
	begin
		if rising_edge(clk) then
			if clk16en = '1' and is_count_mid = '1' then
				if state = S_SHIFT then
					dsr <= rx & dsr(7 downto 1);
				end if;
			end if;
		end if;
	end process;

	-- Rising edge, when data valid
	strobe_i <= '0' when state = S_SHIFT else '1';

	-- From this, we generate a clk wide pulse:

tx_strobe:
	process (clk)
	begin
		if rising_edge(clk) then
			strobeq <= strobe_i;
			data <= dsr;
		end if;
	end process;

	strobe <= not(strobeq) and strobe_i; -- Pulse on rising edge

bitcounter:
	process (clk)
	begin
		if rising_edge(clk) then
			if clk16en = '1' and is_count_begin = '1' then
				case state is
				when S_SHIFT =>
					bitcount <= bitcount + 1;
				when others =>
					bitcount <= "000";
				end case;
			end if;
		end if;
	end process;

-- Framing errors:
detect_frerr:
	process (clk)
	begin
		if rising_edge(clk) then
			if reset = '1' then
				frame_err <= '0';
			elsif state = S_STOP and is_count_mid = '1' and rx = '0' then
				frame_err <= '1';
			end if;
		end if;
	end process;
	


	err_frame <= frame_err;

	-- Debugging:
	d_bitcount  <= bitcount;

end behaviour;

	
