// t_combined.v -- multiple independent boolean cells feeding one output
//
// This is the structural test for the key property of the fix:
//   N independent boolean cells => exactly N std_logic intermediates.
//
// Three independent boolean cells (distinct inputs, no CSE possible),
// OR'd together with a plain signal and a constant into a single 4-bit
// output.  Each boolean cell has Y_WIDTH=4 and must get its own
// std_logic intermediate.  The plain signal and constant require none.
//
// A broken "combined expression" fix would produce one intermediate
// (or none) where three are required.  The test asserts the exact count.
//
// Expected RTLIL: 3 x $logic_and/or/not at Y_WIDTH=4, 4 x $or at Y_WIDTH=4.
// Expected VHDL after fix: exactly 3 'signal nXX : std_logic;' declarations.
module t_combined (
    input  wire [3:0] vec_a,
    input  wire       bool_c, bool_d, bool_e, bool_f,
    output wire [3:0] o
);
    // (bool_c && bool_d): $logic_and Y_WIDTH=4 -- intermediate required
    // (bool_d || bool_e): $logic_or  Y_WIDTH=4 -- intermediate required
    // !bool_f:            $logic_not Y_WIDTH=4 -- intermediate required
    // vec_a:              plain signal          -- no intermediate
    // 4'b1010:            constant              -- no intermediate
    //
    // Each boolean uses distinct inputs so Yosys cannot merge any two:
    //   and: bool_c, bool_d
    //   or:  bool_d, bool_e   (bool_d shared with and -- but different cell type)
    //   not: bool_f           (unique input)
    assign o = (bool_c && bool_d)
             | (bool_d || bool_e)
             | !bool_f
             | vec_a
             | 4'b1010;
endmodule
