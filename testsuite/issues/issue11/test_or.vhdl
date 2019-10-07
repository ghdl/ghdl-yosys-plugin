library ieee;
use ieee.std_logic_1164.all;

entity test_or is port (
    sel0, sel1: in std_logic;
    c: out std_logic);
end test_or;

architecture synth of test_or is
begin

    c <= sel1 or sel0;

end synth;
