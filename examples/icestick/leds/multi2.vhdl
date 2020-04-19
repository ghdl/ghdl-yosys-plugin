architecture multi2 of leds is
  signal clk_4hz: std_logic;
  signal clk_5sec : std_logic;
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
    variable counter5 : unsigned (4 downto 0);
  begin
    if rising_edge (clk) then
      clk_5sec <= '0';
      if clk_4hz = '1' then
        if counter5 = 19 then
          clk_5sec <= '1';
          counter5 := "00000";
        else
          counter5 := counter5 + 1;
        end if;
      end if;
    end if;
  end process;

  led1 <= clk_5sec;
  led2 <= '0';
  led3 <= '0';
  led4 <= '0';
  led5 <= '0';
end multi2;
