// t_pos_1bit.v -- $pos extending a 1-bit signal to a wider type (issue #232)
//
// When a 1-bit wire feeds a wider mux (e.g. via ternary), Yosys inserts a
// $pos cell (A_WIDTH=1, Y_WIDTH=N).  write_vhdl was emitting:
//   resize(unsigned(data), N)
// unsigned() requires std_logic_vector, not std_logic.
// Fix: use dump_sigspec_unsigned for A in $pos, which emits
// unsigned'("" & data) for 1-bit signals.
module t_pos_1bit (
    input  wire       sel,
    input  wire       data,        // 1-bit: becomes std_logic
    input  wire [3:0] bus,         // 4-bit: control, must not regress
    output wire [3:0] o_extend,    // sel ? data : 4'b0  ($pos A_WIDTH=1 Y_WIDTH=4)
    output wire [3:0] o_ctrl       // sel ? bus  : 4'b0  (no $pos: control)
);
    assign o_extend = sel ? data  : 4'b0;  // $pos data 1->4, then $mux
    assign o_ctrl   = sel ? bus   : 4'b0;  // no $pos needed: widths match
endmodule
