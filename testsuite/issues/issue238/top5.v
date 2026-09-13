module sub4(a, b);
  inout [1:0] a;
  wire [1:0] a;
  output [1:0] b;
  wire [1:0] b;
  assign b = a;
endmodule

module top4(a, b, c, d);
  inout [1:0] a;
  wire [1:0] a;
  output [1:0] b;
  wire [1:0] b;
  inout c;
  wire c;
  output d;
  wire d;
  sub4 inst1 (
    .a({a[0], a[1]}),
    .b({b[1], b[0]})
  );
  assign d = c;
endmodule
