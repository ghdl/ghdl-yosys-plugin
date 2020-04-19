architecture blink of leds is
  signal clk_4hz: std_logic;
begin
  process (clk)
    --  3_000_000 is 0x2dc6c0
    variable counter : unsigned (23 downto 0);
  begin
    if rising_edge(clk) then
      if counter = 2_999_999 then
        counter := x"000000";
        clk_4hz <= not clk_4hz;
      else
        counter := counter + 1;
      end if;
    end if;
  end process;

  led1 <= clk_4hz;
  led2 <= clk_4hz;
  led3 <= clk_4hz;
  led4 <= clk_4hz;
  led5 <= clk_4hz;
end blink;
