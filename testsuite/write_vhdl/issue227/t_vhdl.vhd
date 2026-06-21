-- t_vhdl.vhd -- VHDL-sourced round-trip test for write_vhdl
--
-- Exercises three paths used extensively in production designs:
--
--   Signed/unsigned arithmetic:
--     GHDL normalizes signed/unsigned to std_logic_vector before emitting
--     RTLIL.  The write_vhdl output must be valid VHDL-93 with correct
--     std_logic_vector arithmetic.
--
--   Single-bit sub-range slice (std_logic_vector(N downto N)):
--     GHDL normalizes all array ranges to start_offset=0.  write_vhdl
--     must emit std_logic for width-1 wires, not std_logic_vector(0 downto 0).
--
--   Boolean combined with vector (issue #227 equivalent in VHDL):
--     flag OR'd into vec -- confirms the fix works end-to-end via the
--     GHDL import path.
--
-- Requires GHDL (--std=93 or --std=08); analysis uses --std=08 for
-- the resize() and signed/unsigned packages.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity t_vhdl is
    port (
        -- Signed arithmetic: GHDL emits $add with sign-extended operands
        s_a   : in  signed(7 downto 0);
        s_b   : in  signed(7 downto 0);
        o_sum : out signed(8 downto 0);       -- 9-bit sum (guard bit)

        -- Unsigned passthrough
        u_a   : in  unsigned(3 downto 0);
        o_u   : out std_logic_vector(3 downto 0);

        -- Single-bit sub-range slices: must map to std_logic output ports
        bus8  : in  std_logic_vector(7 downto 0);
        o_b2  : out std_logic;                -- bus8(2)
        o_b5  : out std_logic;                -- bus8(5)

        -- Boolean flag OR'd into every bit of vec (issue #227 via VHDL)
        vec   : in  std_logic_vector(3 downto 0);
        flag  : in  std_logic;
        o_flag_vec : out std_logic_vector(3 downto 0)
    );
end entity t_vhdl;

architecture rtl of t_vhdl is
begin
    -- Sign-extending addition
    o_sum <= resize(s_a, 9) + resize(s_b, 9);

    -- Unsigned passthrough via std_logic_vector conversion
    o_u <= std_logic_vector(u_a);

    -- Single-bit slices
    o_b2 <= bus8(2);
    o_b5 <= bus8(5);

    -- Boolean + vector
    o_flag_vec <= vec or (vec'range => flag);
end architecture rtl;
