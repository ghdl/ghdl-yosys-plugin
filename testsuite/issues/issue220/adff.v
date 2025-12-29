module dff
  (input  clk,
   input  ce,
   input  din,
   input  set,
   input  res,
   output q);
  wire n7;
  wire n11;
  wire n12;
  reg n13;
  assign q = n13; //(module output)
  /* adff.vhdl:22:5  */
  assign n7 = res ? 1'b0 : 1'b1;
  /* adff.vhdl:4:8  */
  assign n11 = res | set;
  /* adff.vhdl:24:5  */
  assign n12 = ce ? din : n13;
  /* adff.vhdl:24:5  */
  always @(posedge clk or posedge n11)
    if (n11)
      n13 <= n7;
    else
      n13 <= n12;
endmodule

