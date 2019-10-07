library ieee;
use ieee.std_logic_1164.all;

entity test_xnor is port (
    sel0, sel1: in std_logic;
    c: out std_logic);
end test_xnor;

architecture synth of test_xnor is
begin

    c <= sel1 xnor sel0;

end synth;
