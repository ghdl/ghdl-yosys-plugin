library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package interface is
	constant maxAddrBitBRAMLimit : integer := 32;
	constant minAddrBit : integer := 2;
	constant wordSize : integer := 32;
	type ToROM is record
		memAWriteEnable : std_logic;
		memAAddr : std_logic_vector(maxAddrBitBRAMLimit downto minAddrBit);
		memAWrite : std_logic_vector(wordSize-1 downto 0);
		memBWriteEnable : std_logic;
		memBAddr : std_logic_vector(maxAddrBitBRAMLimit downto minAddrBit);
		memBWrite : std_logic_vector(wordSize-1 downto 0);
	end record;
	type FromROM is record
		memARead : std_logic_vector(wordSize-1 downto 0);
		memBRead : std_logic_vector(wordSize-1 downto 0);
	end record;

end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.interface.all;

entity BootROM is
generic
	(
		maxAddrBitBRAM : integer := 7
	);
port (
	clk : in std_logic;
	areset : in std_logic := '0';
	from_sys : in ToROM;
	to_sys : out FromROM
);
end entity;

architecture arch of BootROM is

type ram_type is array(natural range 0 to ((2**(maxAddrBitBRAM+1))/4)-1) of std_logic_vector(wordSize-1 downto 0);

shared variable ram : ram_type :=
(
     0 => x"84808080",
     1 => x"8c0b8480",
     2 => x"8081e004",
     3 => x"00848080",
     4 => x"808c04ff",
     5 => x"0d800404",
     6 => x"40000017",
     7 => x"00000000",
     8 => x"0b83ffe0",
     9 => x"80080b83",
    10 => x"ffe08408",
    11 => x"0b83ffe0",
    12 => x"88088480",
    13 => x"80809808",
    14 => x"2d0b83ff",
    15 => x"e0880c0b",
    16 => x"83ffe084",
    17 => x"0c0b83ff",
    18 => x"e0800c04",
    19 => x"00000000",
    20 => x"00000000",
    21 => x"00000000",
    22 => x"00000000",
    23 => x"00000000",
    24 => x"71fd0608",
    25 => x"72830609",
    26 => x"81058205",
    27 => x"832b2a83",
    28 => x"ffff0652",
    29 => x"0471fc06",
    30 => x"08728306",
    31 => x"09810583",
	others => x"00000000"
);

attribute no_rw_check: boolean;
attribute no_rw_check of ram : variable is true;

begin

process (clk)
begin
	if (clk'event and clk = '1') then
		if (from_sys.memAWriteEnable = '1') and (from_sys.memBWriteEnable = '1') and (from_sys.memAAddr=from_sys.memBAddr) and (from_sys.memAWrite/=from_sys.memBWrite) then
			report "write collision" severity failure;
		end if;
	
		if (from_sys.memAWriteEnable = '1') then
			ram(to_integer(unsigned(from_sys.memAAddr(maxAddrBitBRAM downto 2)))) := from_sys.memAWrite;
			to_sys.memARead <= from_sys.memAWrite;
		else
			to_sys.memARead <= ram(to_integer(unsigned(from_sys.memAAddr(maxAddrBitBRAM downto 2))));
		end if;
	end if;
end process;

process (clk)
begin
	if (clk'event and clk = '1') then
		if (from_sys.memBWriteEnable = '1') then
			ram(to_integer(unsigned(from_sys.memBAddr(maxAddrBitBRAM downto 2)))) := from_sys.memBWrite;
			to_sys.memBRead <= from_sys.memBWrite;
		else
			to_sys.memBRead <= ram(to_integer(unsigned(from_sys.memBAddr(maxAddrBitBRAM downto 2))));
		end if;
	end if;
end process;

end arch;
