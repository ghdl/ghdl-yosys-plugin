library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity hdmi_design is
    Port ( 
        clk100    : in STD_LOGIC;
        -- Control signals
        led           : out   std_logic_vector(7 downto 0) :=(others => '0');
        sw            : in    std_logic_vector(7 downto 0) :=(others => '0');
        debug_pmod    : out   std_logic_vector(7 downto 0) :=(others => '0');

        --HDMI input signals
        hdmi_rx_cec   : inout std_logic;
        hdmi_rx_hpa   : out   std_logic;
        hdmi_rx_scl   : in    std_logic;
        hdmi_rx_sda   : inout std_logic;
        hdmi_rx_txen  : out   std_logic;
        hdmi_rx_clk_n : in    std_logic;
        hdmi_rx_clk_p : in    std_logic;
        hdmi_rx_n     : in    std_logic_vector(2 downto 0);
        hdmi_rx_p     : in    std_logic_vector(2 downto 0);

        --- HDMI out
        hdmi_tx_cec   : inout std_logic;
        hdmi_tx_clk_n : out   std_logic;
        hdmi_tx_clk_p : out   std_logic;
        hdmi_tx_hpd   : in    std_logic;
        hdmi_tx_rscl  : inout std_logic;
        hdmi_tx_rsda  : inout std_logic;
        hdmi_tx_p     : out   std_logic_vector(2 downto 0);
        hdmi_tx_n     : out   std_logic_vector(2 downto 0);
        -- For dumping symbols
        rs232_tx     : out std_logic      
    );
end hdmi_design;

architecture Behavioral of hdmi_design is
    component hdmi_io is
    Port ( 
        clk100    : in STD_LOGIC;
        -------------------------------
        -- Control signals
        -------------------------------
        clock_locked  : out std_logic;
        data_synced   : out std_logic;
        debug         : out std_logic_vector(7 downto 0);        
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

        pixel_clk     : out std_logic;
        -------------------------------
        -- VGA data recovered from HDMI
        -------------------------------
        in_hdmi_detected : out std_logic;
        in_blank        : out std_logic;
        in_hsync        : out std_logic;
        in_vsync        : out std_logic;
        in_red          : out std_logic_vector(7 downto 0);
        in_green        : out std_logic_vector(7 downto 0);
        in_blue         : out std_logic_vector(7 downto 0);
        is_interlaced   : out std_logic;
        is_second_field : out std_logic;
            
        -------------------------------------
        -- Audio Levels
        -------------------------------------
        audio_channel : out std_logic_vector(2 downto 0);
        audio_de      : out std_logic;
        audio_sample  : out std_logic_vector(23 downto 0);
        
        -----------------------------------
        -- VGA data to be converted to HDMI
        -----------------------------------
        out_blank     : in  std_logic;
        out_hsync     : in  std_logic;
        out_vsync     : in  std_logic;
        out_red       : in  std_logic_vector(7 downto 0);
        out_green     : in  std_logic_vector(7 downto 0);
        out_blue      : in  std_logic_vector(7 downto 0);
        -----------------------------------
        -- For symbol dump or retransmit
        -----------------------------------
        symbol_sync  : out std_logic; -- indicates a fixed reference point in the frame.
        symbol_ch0   : out std_logic_vector(9 downto 0);
        symbol_ch1   : out std_logic_vector(9 downto 0);
        symbol_ch2   : out std_logic_vector(9 downto 0)
    );
    end component;
    signal symbol_sync  : std_logic;
    signal symbol_ch0   : std_logic_vector(9 downto 0);
    signal symbol_ch1   : std_logic_vector(9 downto 0);
    signal symbol_ch2   : std_logic_vector(9 downto 0);

    signal pixel_clk : std_logic;
    signal in_blank  : std_logic;
    signal in_hsync  : std_logic;
    signal in_vsync  : std_logic;
    signal in_red    : std_logic_vector(7 downto 0);
    signal in_green  : std_logic_vector(7 downto 0);
    signal in_blue   : std_logic_vector(7 downto 0);
    signal is_interlaced   : std_logic;
    signal is_second_field : std_logic;
    signal out_blank : std_logic;
    signal out_hsync : std_logic;
    signal out_vsync : std_logic;
    signal out_red   : std_logic_vector(7 downto 0);
    signal out_green : std_logic_vector(7 downto 0);
    signal out_blue  : std_logic_vector(7 downto 0);

    signal audio_channel : std_logic_vector(2 downto 0);
    signal audio_de      : std_logic;
    signal audio_sample  : std_logic_vector(23 downto 0);

    signal debug : std_logic_vector(7 downto 0);
begin
--    debug_pmod <= debug;    
--    led        <= debug;
    
i_hdmi_io: hdmi_io port map ( 
        clk100        => clk100,
        ---------------------
        -- Control signals
        ---------------------
        clock_locked     => open,
        data_synced      => open,
        debug            => debug,
        ---------------------
        -- HDMI input signals
        ---------------------
        hdmi_rx_cec   => hdmi_rx_cec,
        hdmi_rx_hpa   => hdmi_rx_hpa,
        hdmi_rx_scl   => hdmi_rx_scl,
        hdmi_rx_sda   => hdmi_rx_sda,
        hdmi_rx_txen  => hdmi_rx_txen,
        hdmi_rx_clk_n => hdmi_rx_clk_n,
        hdmi_rx_clk_p => hdmi_rx_clk_p,
        hdmi_rx_p     => hdmi_rx_p,
        hdmi_rx_n     => hdmi_rx_n,

        ----------------------
        -- HDMI output signals
        ----------------------
        hdmi_tx_cec   => hdmi_tx_cec,
        hdmi_tx_clk_n => hdmi_tx_clk_n,
        hdmi_tx_clk_p => hdmi_tx_clk_p,
        hdmi_tx_hpd   => hdmi_tx_hpd,
        hdmi_tx_rscl  => hdmi_tx_rscl,
        hdmi_tx_rsda  => hdmi_tx_rsda,
        hdmi_tx_p     => hdmi_tx_p,
        hdmi_tx_n     => hdmi_tx_n,     

        
        pixel_clk => pixel_clk,
        -------------------------------
        -- VGA data recovered from HDMI
        -------------------------------
        in_blank        => in_blank,
        in_hsync        => in_hsync,
        in_vsync        => in_vsync,
        in_red          => in_red,
        in_green        => in_green,
        in_blue         => in_blue,
        is_interlaced   => is_interlaced,
        is_second_field => is_second_field,

        -----------------------------------
        -- For symbol dump or retransmit
        -----------------------------------
        audio_channel => audio_channel,
        audio_de      => audio_de,
        audio_sample  => audio_sample,
        
        -----------------------------------
        -- VGA data to be converted to HDMI
        -----------------------------------
        out_blank => out_blank,
        out_hsync => out_hsync,
        out_vsync => out_vsync,
        out_red   => out_red,
        out_green => out_green,
        out_blue  => out_blue,
        
        symbol_sync  => symbol_sync, 
        symbol_ch0   => symbol_ch0,
        symbol_ch1   => symbol_ch1,
        symbol_ch2   => symbol_ch2
    );
end Behavioral;
