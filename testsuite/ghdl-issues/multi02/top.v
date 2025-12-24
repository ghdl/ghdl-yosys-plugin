module top(
  input [3:0]  a,
  input [3:0]  b,
  input [3:0]  c,
  output [3:0] y
);

   wire [3:0]  t;
   
  xor_generic
  #(
    .WIDTH(4)
  )
  u_xor1 (.a(a),.b(b),.y(t)),
  u_xor2 (.a(t),.b(c),.y(t));
endmodule
