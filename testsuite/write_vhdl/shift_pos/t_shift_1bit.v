// t_shift_1bit.v -- shift with 1-bit operands (issues #231 and related)
//
// Two sub-cases, same root cause: raw unsigned()/signed() on std_logic fails.
//
// 1-bit B (issue #231): to_integer(unsigned(shamt)) where shamt is std_logic.
//   Fix: use dump_sigspec_unsigned(B) -> unsigned'("" & shamt).
//
// 1-bit A: unsigned(flag) where flag is std_logic.
//   Fix: use dump_sigspec_unsigned(A) -> unsigned'("" & flag).
module t_shift_1bit (
    input  wire [4:0] data,     // 5-bit data
    input  wire       flag,     // 1-bit: becomes std_logic
    input  wire       shamt,    // 1-bit shift amount
    output wire [4:0] o_shl_b,  // data << shamt   (1-bit B)
    output wire [4:0] o_shr_b,  // data >> shamt   (1-bit B)
    output wire [4:0] o_shl_a,  // flag << 2       (1-bit A)
    output wire [4:0] o_shr_a,  // flag >> 1       (1-bit A, different const)
    output wire [4:0] o_ctrl    // data >> 2       (control: normal widths)
);
    assign o_shl_b = data << shamt;  // $shl B_WIDTH=1
    assign o_shr_b = data >> shamt;  // $shr B_WIDTH=1
    assign o_shl_a = flag << 2;      // $shl A_WIDTH=1
    assign o_shr_a = flag >> 1;      // $shr A_WIDTH=1
    assign o_ctrl  = data >> 2;      // control: no 1-bit operands
endmodule
