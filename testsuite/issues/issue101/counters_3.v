module counters_3 (input wire c, input wire aload, input wire [3:0]d,
     output reg [3:0] q);
  always @(posedge c, posedge aload) begin
    if (aload)
      q <= d;
    else
      q <= q + 1;
  end
endmodule
