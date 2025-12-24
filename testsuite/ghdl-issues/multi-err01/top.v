module top(
  input  [3:0] a,
  input  [3:0] b,
  output [3:0] y
);

  xor_generic #(4, 5)
  u_xor_generic (
    .a(a),
    .b(b),
    .y(y)
  );

endmodule
