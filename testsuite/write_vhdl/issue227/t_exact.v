// t_exact.v -- exact reproduction of ghdl-yosys-plugin issue #227
//
// write_vhdl must produce valid VHDL-93 for o0 (y_width=3).
// o1 is the same $logic_and but y_width=1; it must be unchanged by any fix.
module t_exact (
    input  wire [2:0] i0,
    input  wire       i1,
    input  wire       i2,
    output wire [2:0] o0,  // $logic_and result zero-extended to 3 bits (broken)
    output wire       o1   // $logic_and result 1 bit (control: must stay correct)
);
    assign o0 = i0 | (i1 && i2);  // y_width=3: was broken
    assign o1 = i1 && i2;         // y_width=1: must remain a direct conditional
endmodule
