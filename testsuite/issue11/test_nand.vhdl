library ieee;
use ieee.std_logic_1164.all;

entity test_nand is port (
    sel0, sel1: in std_logic;
    c: out std_logic);
end test_nand;

architecture synth of test_nand is
begin

    c <= sel1 nand sel0;

end synth;
