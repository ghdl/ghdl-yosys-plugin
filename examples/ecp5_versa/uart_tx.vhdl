-- UART TX implementation
--
-- (c) 2008 - 2015, Martin Strubel <strubel@section5.ch>
--

-- This implementation depends on an external FIFO that can be emptied
-- as follows:
-- When 'data_out_en' == 1 on rising edge of 'clk', 'data' is latched
-- into the shift register and clocked out to the 'tx' pin. The FIFO
-- increments its pointer and asserts the next data byte to 'data'.

library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;      -- for TO_UNSIGNED

entity UARTtx is
	port (
		busy             : out std_logic;
		data             : in  unsigned(7 downto 0);
		data_ready       : in  std_logic;  -- Data in FIFO ready
		data_out_en      : out std_logic;  -- Data out enable
		tx               : out std_logic; -- TX UART
		reset            : in  std_logic;   -- Reset pin, LOW active
		txclken          : in  std_logic;
		clk              : in  std_logic
	);
end UARTtx;

architecture behaviour of UARTtx is

	type uart_state_t is (S_IDLE, S_START, S_SHIFT, S_STOP);

	signal state        :  uart_state_t := S_IDLE;
	signal nextstate    :  uart_state_t;

	-- Data Shift register:
	signal dsr          :  unsigned(7 downto 0) := x"00";
	signal bitcount     :  unsigned(2 downto 0) := "000"; -- Bit counter


begin

sync_state_advance:
	process (clk)
	begin
		if falling_edge(clk) then
			if txclken = '1' then
				if reset = '1' then
					state <= S_IDLE;
				else
					state <= nextstate;
				end if;
			end if;
		end if;
	end process;

state_decode:
	process (state, nextstate, bitcount, data_ready)
	begin
		case state is
		when S_STOP =>
			if data_ready = '1' then
				nextstate <= S_START;
			else
				nextstate <= S_IDLE;
			end if;
		when S_IDLE =>
			if data_ready = '1' then
				nextstate <= S_START;
			else
				nextstate <= S_IDLE;
			end if;
		when S_START =>
			nextstate <= S_SHIFT;
		when S_SHIFT =>
			if bitcount = "000" then
				nextstate <= S_STOP;
			else
				nextstate <= S_SHIFT;
			end if;
		when others =>
			nextstate <= S_IDLE;
		end case;
	end process;

bitcounter:
	process (clk)
	begin
		if rising_edge(clk) then
			if txclken = '1' then
				case state is
				when S_SHIFT =>
					bitcount <= bitcount + 1;
				when others =>
					bitcount <= "000";
				end case;
			end if;
		end if;
	end process;

shift:
	process (clk)
	begin
		if falling_edge(clk) then
			data_out_en <= '0';
			if txclken = '1' then
				case state is
					when S_START =>
						dsr <= data;
						data_out_en <= '1';
						tx <= '0';
					when S_SHIFT =>
						dsr <= '1' & dsr(7 downto 1);
						tx <= dsr(0);
					when others =>
						tx <= '1';
				end case;
			end if;
		end if;
	end process;

	-- d_state <= std_logic_vector(TO_UNSIGNED(uart_state_t'pos(state), 4));
	busy <= '1' when state /= S_IDLE else '0';

end behaviour;
