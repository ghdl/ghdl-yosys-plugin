`timescale 1 ns / 1 ps

module VHI ( Z );
  output Z ;
  supply1 VDD;
  buf (Z , VDD);
endmodule

module VLO ( Z );
  output Z;
  supply0 VSS;
  buf (Z , VSS);
endmodule
