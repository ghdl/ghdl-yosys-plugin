// t_shift_const.v -- shift by a constant amount (issue #230)
//
// Yosys represents the constant shift amount as a 32-bit RTLIL constant.
// write_vhdl was emitting:
//   to_integer(unsigned("00000000000000000000000000000001"))
// A string literal is not a valid operand for unsigned() in VHDL-93.
// Fix: use dump_sigspec_unsigned for B so constants get unsigned'("...").
module t_shift_const (
    input  wire [3:0] a,
    output wire [3:0] o_shl,   // a << 1  ($shl, B is 32-bit constant 1)
    output wire [3:0] o_shr,   // a >> 2  ($shr, B is 32-bit constant 2)
    output wire [3:0] o_sshl,  // a <<< 1 ($sshl, signed left shift)
    output wire [3:0] o_sshr   // a >>> 1 ($sshr, signed right shift)
);
    assign o_shl  = a << 1;
    assign o_shr  = a >> 2;
    assign o_sshl = $signed(a) <<< 1;
    assign o_sshr = $signed(a) >>> 1;
endmodule
