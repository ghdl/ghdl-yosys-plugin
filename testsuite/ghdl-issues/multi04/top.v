module top(
  input [4:0]  a,
  input [4:0]  b,
  input [3:0]  c,
  output [4:0] y
);

   wire [4:0]  t;

  xor_generic #(.WIDTH(5))
   u_xor1 (.a(a),.b(b),.y(t));

   assign t[4] = t[4];
   
  xor_generic #(.WIDTH(4))
   u_xor2 (.a(t),.b(c),.y(y[3:0]));
endmodule
