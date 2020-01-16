architecture spin2 of leds is
  signal clk_4hz: std_logic;
  signal leds : std_ulogic_vector (1 to 8) := "11000000";
begin
  (led1, led2, led3, led4, led5, led6, led7, led8) <= leds;

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
  begin
    if rising_edge(clk) and clk_4hz = '1' then
        --  Rotate
      leds <= (leds (8), leds (1), leds (2), leds (3), leds (4), leds (5), leds (6), leds (7));
    end if;
  end process;
end spin2;
