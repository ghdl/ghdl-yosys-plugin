--
-- Configureable bit size I/O FIFO buffer
--
-- (c) 2010-2013, Martin Strubel <hackfin@section5.ch>
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity FifoBuffer is
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
		reset     : in  std_logic;
		clk       : in  std_logic
	);
end entity FifoBuffer;


architecture behaviour of FifoBuffer is
	constant FULL_COUNT : unsigned(ADDR_W-1 downto 0) := (others => '1');
	constant ZERO_COUNT : unsigned(ADDR_W-1 downto 0) := (others => '0');

	constant INACTIVE_WRITE_PORT :
		unsigned(DATA_W-1 downto 0) := (others => '0');
	signal iptr  : unsigned(ADDR_W-1 downto 0) := ZERO_COUNT;
	signal optr  : unsigned(ADDR_W-1 downto 0) := ZERO_COUNT;
	signal next_iptr  : unsigned(ADDR_W-1 downto 0) := ZERO_COUNT;
	signal next_optr  : unsigned(ADDR_W-1 downto 0) := ZERO_COUNT;
	signal over  : std_logic := '0';

	signal rdata  : unsigned(DATA_W-1 downto 0);

	type state_t is (S_IDLE, S_READY, S_FULL, S_ERROR);
	-- GHDLSYNTH_QUIRK
	-- Needs this initialized, otherwise gets 'optimized away'
	signal state : state_t := S_IDLE;
	-- If we don't initialize, yosys feels like it wants to recode.
	-- signal state : state_t;

	signal int_full      : std_logic; -- Internal "full" flag
	signal int_rden      : std_logic;
	signal int_rden_d    : std_logic;
	signal maybe_full    : std_logic;
	signal maybe_empty   : std_logic;

	signal dready        : std_logic;

	component bram_2psync is
		generic (
			ADDR      : natural := 6;
			DATA      : natural := 16
		);
		port (
			-- Port A
			a_we    : in  std_logic;
			a_addr  : in  unsigned(ADDR-1 downto 0);
			a_write : in  unsigned(DATA-1 downto 0);
			a_read  : out unsigned(DATA-1 downto 0);
			-- Port B
			b_we    : in  std_logic;
			b_addr  : in  unsigned(ADDR-1 downto 0);
			b_write : in  unsigned(DATA-1 downto 0);
			b_read  : out unsigned(DATA-1 downto 0);
			clk     : in  std_logic
		);
	end component bram_2psync;

begin

count:
	process(clk)
	begin
		if rising_edge(clk) then
			if reset = '1' then
				optr <= ZERO_COUNT;
				iptr <= ZERO_COUNT;
			else 
				if wren = '1' then
					iptr <= next_iptr;
				end if;
				if int_rden = '1' then
					optr <= next_optr;
				end if;
			end if;
		end if;
	end process;

	next_iptr <= iptr + 1;
	next_optr <= optr + 1;

	-- These are ambiguous signals, need evaluation of wren/rden!
	maybe_full   <= '1' when optr = next_iptr else '0';
	maybe_empty  <= '1' when iptr = next_optr else '0';

	dready  <= '1' when state = S_READY or state = S_FULL else '0';

fsm:
	process(clk)
	begin
		if rising_edge(clk) then
			if reset = '1' then
				state <= S_IDLE;
			else
				case state is
				when S_IDLE =>
					if wren = '1' then
						state <= S_READY;
					else
						state <= S_IDLE;
					end if;
				when S_READY =>
					if wren = '1' then
						-- We're just getting full
						if maybe_full = '1' and int_rden = '0' then
							state <= S_FULL;
						end if;
					-- We're just getting empty
					elsif maybe_empty = '1' and int_rden = '1' then
						state <= S_IDLE;
					end if;
					-- All other conditions: Remain S_READY
				when S_FULL =>
					if wren = '1' then
						-- It is actually allowed to read and write
						-- simultaneously while FULL.
						if int_rden = '0' then
							state <= S_ERROR;
						else
							state <= S_FULL;
						end if;
					elsif int_rden = '1' then
						state <= S_READY;
					else
						state <= S_FULL;
					end if;
				when S_ERROR =>
				end case;
			end if;
		end if;
	end process;

	over   <= '1' when state = S_ERROR else '0';
	err <= over;

ram:
	bram_2psync
	generic map ( ADDR => ADDR_W, DATA => DATA_W)
	port map (
		a_we    => '0',
		a_addr  => optr,
		a_write => INACTIVE_WRITE_PORT,
		a_read  => rdata,
		b_we    => wren,
		b_addr  => iptr,
		b_write => idata,
		b_read  => open,
		clk => clk
	);


-- This section appends a little pre-read unit to the FIFO
-- to allow higher speed on most architectures.

gen_register:
	if EXTRA_REGISTER generate

	int_rden <= (not int_full or rden) and dready;
preread:
 	process(clk)
 	begin
 		if rising_edge(clk) then
			if reset = '1' then
				int_full <= '0';
			elsif dready = '1' then
				if int_full = '0' then
					int_full <= '1';
					oready <= '1';
				end if;
			elsif int_full = '1' then
				if rden = '1' then
					oready <= '0';
					int_full <= '0';
				else
					oready <= '1';
				end if;
			else
				oready <= '0';
			end if;
			
			int_rden_d <= int_rden;
			if int_rden_d = '1' then
				odata <= rdata;
			end if;
		end if;
	end process;
	end generate;


gen_direct:
	if not EXTRA_REGISTER generate
		int_full <= '1' when state = S_FULL else '0';
		int_rden <= rden;
		odata <= rdata;
		oready <= dready;
	end generate;

	iready <= not int_full;


-- synthesis translate_off

-- Synplify barfs on this, we need to comment out the whole shlorm.

errguard:
	process(clk)
	begin
		if rising_edge(clk) then
			if over = '1' then
				assert false report "FIFO overrun in " & behaviour'path_name
				severity failure;
			end if;
		end if;
	end process;

-- synthesis translate_on

end behaviour;
