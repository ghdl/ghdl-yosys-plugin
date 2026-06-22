// t_shift_1bit.v -- shift by a 1-bit signal (issue #231)
//
// When the shift amount B has width 1, it is std_logic in VHDL.
// write_vhdl was emitting:
//   to_integer(unsigned(i1))
// unsigned() requires std_logic_vector, not std_logic.
// Fix: use dump_sigspec_unsigned for B, which emits unsigned'("" & i1).
module t_shift_1bit (
    input  wire [4:0] a,
    input  wire       shamt,   // 1-bit shift amount
    output wire [4:0] o_shl,   // a << shamt  ($shl, B_WIDTH=1)
    output wire [4:0] o_shr,   // a >> shamt  ($shr, B_WIDTH=1)
    output wire [4:0] o_ctrl   // a >> 2 (control: constant, must also be correct)
);
    assign o_shl  = a << shamt;
    assign o_shr  = a >> shamt;
    assign o_ctrl = a >> 2;    // constant shift: control that fix doesn't break this
endmodule
