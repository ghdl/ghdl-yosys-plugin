----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 04/08/2020 11:41:37 AM
-- Design Name: 
-- Module Name: axis_squarer - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity axis_squarer is
    Port ( clk : in STD_LOGIC;
           aresetn : in STD_LOGIC;
           s_axis_tdata : in STD_LOGIC_VECTOR (31 downto 0);
           s_axis_tlast : in STD_LOGIC;
           s_axis_tvalid : in STD_LOGIC;
           s_axis_tready : out STD_LOGIC;
           
           m_axis_tdata : out STD_LOGIC_VECTOR (31 downto 0);
           m_axis_tlast : out STD_LOGIC;
           m_axis_tvalid : out STD_LOGIC;
           m_axis_tready : in STD_LOGIC);
end axis_squarer;

architecture Behavioral of axis_squarer is
    signal idle_counter: UNSIGNED(7 downto 0) := (others => '0');
    signal counter_start_long: UNSIGNED(3 downto 0) := (others => '0');
    type FSM_STATES is (IDLE, TX_RESULT, LONG_COMPUTATION);
    signal fsm: FSM_STATES := IDLE;
begin
    fsm_main: process(clk) is
    begin
        if rising_edge(clk) then
            if aresetn = '0' then
                fsm <= IDLE;
                -- Reset stuff added below in response to fv
                m_axis_tlast <= '0';
                counter_start_long <= (others => '0');
            else
                case fsm is
                when IDLE =>
                    -- Wait for input valid, then put data onto output bus
                    if s_axis_tvalid = '1' then
                        m_axis_tdata <= not s_axis_tdata;
                        if s_axis_tlast = '1' or counter_start_long = 2 then
                            m_axis_tlast <= '1';
                        else
                            m_axis_tlast <= '0';
                        end if;
                        fsm <= TX_RESULT;
                    end if;
                when TX_RESULT =>
                    -- Wait for output ready
                    -- Do 8 fast returns before a single slow return
                    if m_axis_tready = '1' then
                        m_axis_tlast <= '0';
                        counter_start_long <= counter_start_long+1;
                        if counter_start_long = 2 then
                            fsm <= LONG_COMPUTATION;
                            counter_start_long <= (others => '0');
                        else
                            fsm <= IDLE;
                        end if;
                    end if;
                when LONG_COMPUTATION =>
                    -- Wait for 16 cycles
                    -- In actuality a longer computation goes here but simplify by reducing it to a wait
                    idle_counter <= idle_counter + 1;
                    if idle_counter = 5 then
                        fsm <= IDLE;
                    end if;
                end case;
            end if;
        end if;
    end process;
    
    fsm_axis_handshake_outputs: process(fsm,aresetn) is
    begin
        case fsm is
            when IDLE =>
                s_axis_tready <= aresetn; -- Ready when not reset
                m_axis_tvalid <= '0';
            when TX_RESULT =>
                s_axis_tready <= '0';
                m_axis_tvalid <= '1';
            when LONG_COMPUTATION =>
                s_axis_tready <= '0';
                m_axis_tvalid <= '0';
        end case;
    end process;
end Behavioral;
