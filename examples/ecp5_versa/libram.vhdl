-- Common RAM library package
-- For MIPS specific RAM package: see pkg_ram.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package ram is

	-- Unconstrained 16 bit RAM initialization type
	type ram16_init_t is array(natural range <>) of
		unsigned(15 downto 0);
		
	-- Unconstrained 32 bit RAM initialization type
	type ram32_init_t is array(natural range <>) of
		unsigned(31 downto 0);

	component DPRAM16_init is
		generic (
			ADDR_W      : natural := 6;
			DATA_W      : natural := 16;
			INIT_DATA   : ram16_init_t;
			SYN_RAMTYPE : string := "block_ram"
		);
		port (
			clk     : in  std_logic;
			-- Port A
			a_we    : in  std_logic;
			a_addr  : in  unsigned(ADDR_W-1 downto 0);
			a_write : in  unsigned(DATA_W-1 downto 0);
			a_read  : out unsigned(DATA_W-1 downto 0);
			-- Port B
			b_we    : in  std_logic;
			b_addr  : in  unsigned(ADDR_W-1 downto 0);
			b_write : in  unsigned(DATA_W-1 downto 0);
			b_read  : out unsigned(DATA_W-1 downto 0)
		);
	end component DPRAM16_init;

	component DPRAM16_init_ce is
		generic (
			ADDR_W      : natural := 6;
			DATA_W      : natural := 16;
			INIT_DATA   : ram16_init_t;
			SYN_RAMTYPE : string := "block_ram"
		);
		port (
			clk     : in  std_logic;
			-- Port A
			a_ce    : in  std_logic;
			a_we    : in  std_logic;
			a_addr  : in  unsigned(ADDR_W-1 downto 0);
			a_write : in  unsigned(DATA_W-1 downto 0);
			a_read  : out unsigned(DATA_W-1 downto 0);
			-- Port B
			b_ce    : in  std_logic;
			b_we    : in  std_logic;
			b_addr  : in  unsigned(ADDR_W-1 downto 0);
			b_write : in  unsigned(DATA_W-1 downto 0);
			b_read  : out unsigned(DATA_W-1 downto 0)
		);
	end component DPRAM16_init_ce;

	component DPRAM16_init_hex_ce is
		generic (
			ADDR_W      : natural := 6;
			DATA_W      : natural := 16;
			INIT_DATA   : string  := "mem.hex";
			SYN_RAMTYPE : string  := "block_ram"
		);
		port (
			-- Port A
			a_clk   : in  std_logic;
			a_ce    : in  std_logic;
			a_we    : in  std_logic;
			a_addr  : in  unsigned(ADDR_W-1 downto 0);
			a_write : in  unsigned(DATA_W-1 downto 0);
			a_read  : out unsigned(DATA_W-1 downto 0);
			-- Port B
			b_clk   : in  std_logic;
			b_ce    : in  std_logic;
			b_we    : in  std_logic;
			b_addr  : in  unsigned(ADDR_W-1 downto 0);
			b_write : in  unsigned(DATA_W-1 downto 0);
			b_read  : out unsigned(DATA_W-1 downto 0)
		);
	end component DPRAM16_init_hex_ce;

	component DPRAM_init_hex is
		generic (
			ADDR_W      : natural := 6;
			DATA_W      : natural := 32;
			INIT_DATA   : string  := "mem32.hex";
			SYN_RAMTYPE : string := "block_ram"
		);
		port (
			clk     : in  std_logic;
			-- Port A
			a_ce    : in  std_logic;
			a_we    : in  std_logic;
			a_addr  : in  unsigned(ADDR_W-1 downto 0);
			a_write : in  unsigned(DATA_W-1 downto 0);
			a_read  : out unsigned(DATA_W-1 downto 0);
			-- Port B
			b_ce    : in  std_logic;
			b_we    : in  std_logic;
			b_addr  : in  unsigned(ADDR_W-1 downto 0);
			b_write : in  unsigned(DATA_W-1 downto 0);
			b_read  : out unsigned(DATA_W-1 downto 0)
		);
	end component DPRAM_init_hex;


	component DPRAM32_init is
		generic (
			ADDR_W      : natural := 6;
			DATA_W      : natural := 32;
			INIT_DATA   : ram32_init_t;
			SYN_RAMTYPE : string := "block_ram"
		);
		port (
			clk     : in  std_logic;
			-- Port A
			a_we    : in  std_logic;
			a_addr  : in  unsigned(ADDR_W-1 downto 0);
			a_write : in  unsigned(DATA_W-1 downto 0);
			a_read  : out unsigned(DATA_W-1 downto 0);
			-- Port B
			b_we    : in  std_logic;
			b_addr  : in  unsigned(ADDR_W-1 downto 0);
			b_write : in  unsigned(DATA_W-1 downto 0);
			b_read  : out unsigned(DATA_W-1 downto 0)
		);
	end component DPRAM32_init;

	component DPRAM is
		generic (
			ADDR_W      : natural := 6;
			DATA_W      : natural := 16;
			EN_BYPASS   : boolean := false;
			SYN_RAMTYPE : string := "block_ram"
		);
		port (
			clk   : in  std_logic;
			-- Port A
			a_we    : in  std_logic;
			a_addr  : in  unsigned(ADDR_W-1 downto 0);
			a_write : in  unsigned(DATA_W-1 downto 0);
			a_read  : out unsigned(DATA_W-1 downto 0);
			-- Port B
			b_we    : in  std_logic;
			b_addr  : in  unsigned(ADDR_W-1 downto 0);
			b_write : in  unsigned(DATA_W-1 downto 0);
			b_read  : out unsigned(DATA_W-1 downto 0)
		);
	end component DPRAM;

	component DPRAM_clk2
		generic(
			ADDR_W      : natural := 6;
			DATA_W      : natural := 16;
			EN_BYPASS   : boolean := true;
			SYN_RAMTYPE : string := "block_ram"
		);
		port(
		a_clk   : in  std_logic;
		-- Port A
		a_we    : in  std_logic;
		a_addr  : in  unsigned(ADDR_W-1 downto 0);
		a_write : in  unsigned(DATA_W-1 downto 0);
		a_read  : out unsigned(DATA_W-1 downto 0);
		-- Port B
		b_clk   : in  std_logic;
		b_we    : in  std_logic;
		b_addr  : in  unsigned(ADDR_W-1 downto 0);
		b_write : in  unsigned(DATA_W-1 downto 0);
		b_read  : out unsigned(DATA_W-1 downto 0)
	);
	end component;

	component bram_2psync is
		generic (
			ADDR_W      : natural := 6;
			DATA_W      : natural := 16;
			SYN_RAMTYPE : string := "block_ram"
		);
		port (
			-- Port A
			a_we    : in  std_logic;
			a_addr  : in  unsigned(ADDR_W-1 downto 0);
			a_write : in  unsigned(DATA_W-1 downto 0);
			a_read  : out unsigned(DATA_W-1 downto 0);
			-- Port B
			b_we    : in  std_logic;
			b_addr  : in  unsigned(ADDR_W-1 downto 0);
			b_write : in  unsigned(DATA_W-1 downto 0);
			b_read  : out unsigned(DATA_W-1 downto 0);
			clk     : in  std_logic
		);
	end component bram_2psync;

end package;
