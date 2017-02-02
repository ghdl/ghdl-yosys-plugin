architecture rotate1 of leds is
  signal clk_4hz: std_logic;
begin
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
      count := count + 1;
      if count = 0 then
        led1 <= '1';
        led2 <= '0';
        led3 <= '0';
        led4 <= '0';
        led5 <= '1';
      elsif count = 1 then
        led1 <= '0';
        led2 <= '1';
        led3 <= '0';
        led4 <= '0';
        led5 <= '0';
      elsif count = 2 then
        led1 <= '0';
        led2 <= '0';
        led3 <= '1';
        led4 <= '0';
        led5 <= '1';
      else
        led1 <= '0';
        led2 <= '0';
        led3 <= '0';
        led4 <= '1';
        led5 <= '0';
      end if;
    end if;
  end process;
end rotate1;
