library ieee;
use ieee.std_logic_1164.all;

entity test_xor is port (
    sel0, sel1: in std_logic;
    c: out std_logic);
end test_xor;

architecture synth of test_xor is
begin

    c <= sel1 xor sel0;

end synth;
