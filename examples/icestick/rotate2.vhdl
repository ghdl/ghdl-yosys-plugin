architecture rotate2 of leds is
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
        (led1, led2, led3, led4, led5) <= unsigned'("10001");
      elsif count = 1 then
        (led1, led2, led3, led4, led5) <= unsigned'("01000");
      elsif count = 2 then
        (led1, led2, led3, led4, led5) <= unsigned'("00101");
      else
        (led1, led2, led3, led4, led5) <= unsigned'("00010");
      end if;
    end if;
  end process;
end rotate2;
