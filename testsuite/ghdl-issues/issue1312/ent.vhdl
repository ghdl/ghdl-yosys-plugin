library ieee;
use ieee.std_logic_1164.all;

entity ent is
    port (
        a      : inout std_logic := '0';
        d_out  : out std_logic
    );
end;

architecture a of ent is
begin
    d_out <= a;
end;
