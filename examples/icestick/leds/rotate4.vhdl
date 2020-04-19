architecture rotate4 of leds is
  signal clk_4hz: std_logic;
  signal leds : std_ulogic_vector (1 to 5);
begin
  (led1, led2, led3, led4, led5) <= leds;

  process (clk)
    --  3_000_000 is 0x2dc6c0
    variable counter : unsigned (23 downto 0);
  begin
    if rising_edge(clk) then
      if counter = 2_999_999 then
        counter := x"000000";
        clk_4hz <= '1';
      else
        counter := counter + 1;
        clk_4hz <= '0';
      end if;
    end if;
  end process;

  process (clk)
    variable count : unsigned (1 downto 0);
  begin
    if rising_edge(clk) and clk_4hz = '1' then
      case count is
        when "00" =>
          leds <= "10001";
        when "01" =>
          leds <= "01000";
        when "10" =>
          leds <= "00101";
        when "11" =>
          leds <= "00010";
        when others =>
          null;
      end case;
      count := count + 1;
    end if;
  end process;
end rotate4;
