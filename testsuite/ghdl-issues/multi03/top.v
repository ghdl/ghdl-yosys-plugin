module top(
  input [1:0]  a,
  input [1:0]  b,
  input [3:0]  c,
  output [3:0] y
);

   wire [3:0]  t;

   assign t[3:1] = 2'b0;

  xor_generic #(.WIDTH(2))
   u_xor1 (.a(a),.b(b),.y(t[1:0]));
   
  xor_generic #(.WIDTH(4))
   u_xor2 (.a(t),.b(c),.y(t));
endmodule
