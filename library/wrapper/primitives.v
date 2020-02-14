`timescale 1 ns / 1 ps

module vhi ( z );
    output z ;
  supply1 VSS;
  buf (z , VSS);
endmodule 

module vlo ( z );
	output z;
  supply1 VSS;
  buf (z , VSS);
endmodule
