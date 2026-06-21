// t_logic.v -- $logic_and, $logic_or, $logic_not with y_width > 1
//
// Each cell type is exercised at two output widths:
//   y_width=4  (broken path): must produce one std_logic intermediate each
//   y_width=1  (control):     must stay as direct '1' when COND else '0'
//
// Inputs are rotated between the y_width=4 and y_width=1 outputs so Yosys
// cannot merge them via CSE.
//
// Expected RTLIL: 3 x $logic_and/or/not at Y_WIDTH=4, 3 at Y_WIDTH=1.
// Expected VHDL after fix: 3 new 'signal nXX : std_logic;' declarations,
// 3 existing 'signal nXX : std_logic;' for the y_width=1 internal wires.
module t_logic (
    input  wire bool_c, bool_d, bool_e, bool_f,
    output wire [3:0] o_and4,   // $logic_and y_width=4  (broken before fix)
    output wire [3:0] o_or4,    // $logic_or  y_width=4  (broken before fix)
    output wire [3:0] o_not4,   // $logic_not y_width=4  (broken before fix)
    output wire       o_and1,   // $logic_and y_width=1  (control: must be unchanged)
    output wire       o_or1,    // $logic_or  y_width=1  (control: must be unchanged)
    output wire       o_not1    // $logic_not y_width=1  (control: must be unchanged)
);
    assign o_and4 = bool_c && bool_d;   // $logic_and Y_WIDTH=4
    assign o_or4  = bool_c || bool_e;   // $logic_or  Y_WIDTH=4
    assign o_not4 = !bool_d;            // $logic_not Y_WIDTH=4

    assign o_and1 = bool_e && bool_f;   // $logic_and Y_WIDTH=1 -- different inputs
    assign o_or1  = bool_d || bool_f;   // $logic_or  Y_WIDTH=1 -- different inputs
    assign o_not1 = !bool_f;            // $logic_not Y_WIDTH=1 -- different input
endmodule
