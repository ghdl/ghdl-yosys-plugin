library ieee;
use ieee.std_logic_1164.all;

entity demux is port (
   j :  in integer range 0 to 3;
   k :  in std_logic;
   l :  in std_logic;
   y : out std_logic_vector(1 to 5));
end demux;

architecture beh of demux is

   function to_slv(C:integer; B:std_logic; E:std_logic) return std_logic_vector is
   variable ret : std_logic_vector(1 to 5) := (others => '0');
   begin
      ret(C+1) := E;
      ret(5)   := B;

      return ret;
   end to_slv;
begin
   y <= to_slv(j, k, l);
end beh;
