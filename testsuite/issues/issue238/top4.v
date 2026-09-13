module sub4(a, b);
  inout a;
  wire a;
  output b;
  wire b;
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
    .a(a[0]),
    .b(b[1])
  );
  sub4 inst2 (
    .a(a[1]),
    .b(b[0])
  );
  assign d = c;
endmodule
