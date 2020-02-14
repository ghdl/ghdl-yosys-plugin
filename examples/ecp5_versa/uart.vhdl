-- Simple UART core implementation
--
-- <hackfin@section5.ch>

library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
	use work.system_map.all;

entity uart_core is
	generic (
		FIFO_DEPTH : natural := 6;
		-- Note: Currently ineffective. See library/wrappers/bram.v
		SYN_RAMTYPE  : string  := "distributed"
	);
	port (
		tx        : out std_logic;
		rx        : in std_logic;
		rxirq     : out std_logic;
		ctrl      : in uart_WritePort;
		stat      : out uart_ReadPort;
		clk       : in std_logic
	);

end uart_core;

architecture behaviour of uart_core is

	signal count16  : unsigned(4-1 downto 0) := (others => '0');
	signal counter  : unsigned(16-1 downto 0) := (others => '0');

	signal strobe_rx     : std_logic;
	signal rxd           : unsigned(7 downto 0);
	signal txd           : unsigned(7 downto 0);

	signal rxfifo_data   : unsigned(7 downto 0);

	signal rxfifo_rden   : std_logic;
	signal txfifo_wren   : std_logic;

	signal rxdata_ready  : std_logic;

	signal txfifo_dready : std_logic;
	signal txfifo_strobe : std_logic;

	signal clk16_enable  : std_logic;
	signal txclk_enable  : std_logic;

	component FifoBuffer is
		generic (
			ADDR_W          : natural := 6;
			DATA_W          : natural := 16;
			EXTRA_REGISTER  : boolean := false;
			SYN_RAMTYPE     : string  := "block_ram"
		);
		port (
			-- Write enable
			wren      : in  std_logic;
			idata     : in  unsigned(DATA_W-1 downto 0);
			iready    : out std_logic;
			-- Data stream output:
			odata     : out unsigned(DATA_W-1 downto 0);
			oready    : out std_logic;
			rden      : in  std_logic;
			err       : out std_logic;
			-- debug     : out unsigned(16-1 downto 0);
			reset     : in  std_logic;
			clk       : in  std_logic
		);
	end component FifoBuffer;


begin

-- Clock divider:
clkdiv:
	process (clk)
	begin
		if rising_edge(clk) then
			clk16_enable <= '0';
			txclk_enable <= '0';
			-- Important to reset, otherwise, the counter might run away...
			if ctrl.uart_reset = '1' then
				counter <= (others => '0');
			elsif counter = ctrl.uart_clkdiv then
				counter <= (others => '0');
				clk16_enable <= '1';
				count16 <= count16 + 1;
				if count16 = "1111" then
					txclk_enable <= '1';
				end if;
			else
				counter <= counter + 1;
			end if;
		end if;
	end process;

	rxfifo_rden <= ctrl.select_uart_rxr and rxdata_ready;
	txfifo_wren <= ctrl.select_uart_txr;

uart_rx: entity work.UARTrx
	port map (
		d_bitcount       => stat.bitcount,
		rx               => rx,
		-- Data
		err_frame        => stat.frerr,
		data             => rxd,
		strobe           => strobe_rx,
		reset            => ctrl.uart_reset,
		clk16en          => clk16_enable,
		clk              => clk
	);

uart_tx:
	entity work.UARTtx
	port map (
		busy             => stat.txbusy,
		data             => txd,
		data_ready       => txfifo_dready,
		data_out_en      => txfifo_strobe,
		tx               => tx,
		reset            => ctrl.uart_reset,
		txclken          => txclk_enable,
		clk              => clk
	);


rxfifo:
	FifoBuffer
	generic map (
		DATA_W => 8,
		ADDR_W => FIFO_DEPTH,
		SYN_RAMTYPE => SYN_RAMTYPE
	)
	port map (
		wren      => strobe_rx,
		idata     => rxd,
		iready    => open,
		odata     => rxfifo_data,
		oready    => rxdata_ready,
		rden      => rxfifo_rden,
		err       => stat.rxovr,
		reset     => ctrl.uart_reset,
		clk       => clk
	);

	stat.rxdata   <= rxfifo_data;
	stat.dvalid   <= rxdata_ready;
	stat.rxready  <= rxdata_ready;
	rxirq         <= rxdata_ready and ctrl.rx_irq_enable;

txfifo:
	FifoBuffer
	generic map (
		DATA_W => 8,
		ADDR_W => FIFO_DEPTH,
		SYN_RAMTYPE => SYN_RAMTYPE
	)
	port map (
		wren      => txfifo_wren,
		idata     => ctrl.uart_txr,
		iready    => stat.txready,
		odata     => txd,
		oready    => txfifo_dready,
		rden      => txfifo_strobe,
		err       => stat.txovr,
		reset     => ctrl.uart_reset,
		clk       => clk
	);

end behaviour;

	
