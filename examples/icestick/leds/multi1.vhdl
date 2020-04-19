architecture multi1 of leds is
  signal clk_4hz: std_logic;
  signal clk_5sec : std_logic;
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
  
  process (clk)
    variable count : unsigned (1 downto 0);
    variable pat_count : unsigned (0 downto 0);
  begin
    if rising_edge(clk) then
      if clk_4hz = '1' then
         case pat_count is
           when "0" =>
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
           when "1" =>
              case count is
                when "00" =>
                  leds <= "10000";
                when "01" =>
                  leds <= "01011";
                when "10" =>
                  leds <= "00100";
                when "11" =>
                  leds <= "01011";
                when others =>
                  null;
              end case;
           when others =>
             null;
         end case;
         count := count + 1;
      end if;
      if clk_5sec = '1' then
        pat_count := pat_count + 1;
        count := "00";
      end if;
    end if;
  end process;
end multi1;
