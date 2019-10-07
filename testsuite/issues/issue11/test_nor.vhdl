library ieee;
use ieee.std_logic_1164.all;

entity test_nor is port (
    sel0, sel1: in std_logic;
    c: out std_logic);
end test_nor;

architecture synth of test_nor is
begin

    c <= sel1 nor sel0;

end synth;
