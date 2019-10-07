architecture synth of vector is

signal v : std_logic_vector(7 downto 0);

begin

  -- It works ok
  --(led7, led6, led5, led4, led3, led2, led1, led0) <= std_logic_vector'("10101010");

  -- It is assigned in reverse order (led7 should be MSB, but it is assigned
  -- the lsb. led0 should be the lsb, but is assigned as the MSB)
  v <= std_logic_vector'("10101010");
  led7 <= v(7);
  led6 <= v(6);
  led5 <= v(5);
  led4 <= v(4);
  led3 <= v(3);
  led2 <= v(2);
  led1 <= v(1);
  led0 <= v(0);

end synth;

architecture ok of vector is
  signal v : std_logic_vector(7 downto 0);
begin
  -- It works ok
  (led7, led6, led5, led4, led3, led2, led1, led0) <= std_logic_vector'("10101010");
end ok;
