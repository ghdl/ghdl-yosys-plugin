library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity hdmi_io is
    port (
        clk100        : in STD_LOGIC;
        -------------------------------
        -- Control signals
        -------------------------------
        clock_locked   : out std_logic;
        data_synced    : out std_logic;
        debug          : out std_logic_vector(7 downto 0);        
        
        -------------------------------
        --HDMI input signals
        -------------------------------
        hdmi_rx_cec   : inout std_logic;
        hdmi_rx_hpa   : out   std_logic;
        hdmi_rx_scl   : in    std_logic;
        hdmi_rx_sda   : inout std_logic;
        hdmi_rx_txen  : out   std_logic;
        hdmi_rx_clk_n : in    std_logic;
        hdmi_rx_clk_p : in    std_logic;
        hdmi_rx_n     : in    std_logic_vector(2 downto 0);
        hdmi_rx_p     : in    std_logic_vector(2 downto 0);
        
        -------------
        -- HDMI out
        -------------
        hdmi_tx_cec   : inout std_logic;
        hdmi_tx_clk_n : out   std_logic;
        hdmi_tx_clk_p : out   std_logic;
        hdmi_tx_hpd   : in    std_logic;
        hdmi_tx_rscl  : inout std_logic;
        hdmi_tx_rsda  : inout std_logic;
        hdmi_tx_p     : out   std_logic_vector(2 downto 0);
        hdmi_tx_n     : out   std_logic_vector(2 downto 0);
        
        pixel_clk : out std_logic;
        -------------------------------
        -- VGA data recovered from HDMI
        -------------------------------
        in_hdmi_detected : out std_logic;
        in_blank  : out std_logic;
        in_hsync  : out std_logic;
        in_vsync  : out std_logic;
        in_red    : out std_logic_vector(7 downto 0);
        in_green  : out std_logic_vector(7 downto 0);
        in_blue   : out std_logic_vector(7 downto 0);
        is_interlaced   : out std_logic;
        is_second_field : out std_logic;
        
        -----------------------------------
        -- VGA data to be converted to HDMI
        -----------------------------------
        out_blank : in  std_logic;
        out_hsync : in  std_logic;
        out_vsync : in  std_logic;
        out_red   : in  std_logic_vector(7 downto 0);
        out_green : in  std_logic_vector(7 downto 0);
        out_blue  : in  std_logic_vector(7 downto 0);
       -------------------------------------
        -- Audio Levels
        -------------------------------------
        audio_channel : out std_logic_vector(2 downto 0);
        audio_de      : out std_logic;
        audio_sample  : out std_logic_vector(23 downto 0);
        
        -----------------------------------
        -- For symbol dump or retransmit
        -----------------------------------
        symbol_sync  : out std_logic; -- indicates a fixed reference point in the frame.
        symbol_ch0   : out std_logic_vector(9 downto 0);
        symbol_ch1   : out std_logic_vector(9 downto 0);
        symbol_ch2   : out std_logic_vector(9 downto 0)
    );
end entity;

architecture Behavioral of hdmi_io is

    signal fourfourfour_V     : std_logic_vector(11 downto 0);
    signal fourfourfour_W     : std_logic_vector(11 downto 0);

    component conversion_to_RGB is
        port ( clk            : in std_Logic;
               in_V           : in std_logic_vector(11 downto 0);
               in_W           : in std_logic_vector(11 downto 0);
               out_R          : out std_logic_vector(11 downto 0);
               out_G          : out std_logic_vector(11 downto 0)
          );
    end component;

    signal rgb_R     : std_logic_vector(11 downto 0);
    signal rgb_G     : std_logic_vector(11 downto 0);
begin

i_conversion_to_RGB: conversion_to_RGB 
    port map (
           clk              => clk100,
           in_V             => fourfourfour_V,
           in_W             => fourfourfour_W,
           out_G            => rgb_G,
           out_R            => rgb_R
    );

    in_green <= rgb_G(11 downto 4);
    in_red   <= rgb_R(11 downto 4);


end Behavioral;
