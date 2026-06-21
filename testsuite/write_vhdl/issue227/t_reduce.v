// t_reduce.v -- $reduce_and, $reduce_or, $reduce_xor, $reduce_xnor with y_width > 1
//
// Each cell type is exercised at two output widths:
//   y_width=4  (broken path): must produce one std_logic intermediate each
//   y_width=1  (control):     must stay as direct '1' when COND else '0'
//
// vec_a drives the y_width=4 outputs; vec_b drives the y_width=1 controls
// so Yosys cannot merge them via CSE.
//
// $reduce_xnor has zero prior test coverage at any width.
//
// Expected RTLIL: 4 x reduce_* at Y_WIDTH=4, 4 at Y_WIDTH=1.
// Expected VHDL after fix: 4 new 'signal nXX : std_logic;' declarations.
module t_reduce (
    input  wire [3:0] vec_a,
    input  wire [3:0] vec_b,
    output wire [3:0] o_and4,    // $reduce_and  y_width=4  (broken before fix)
    output wire [3:0] o_or4,     // $reduce_or   y_width=4  (broken before fix)
    output wire [3:0] o_xor4,    // $reduce_xor  y_width=4  (broken before fix)
    output wire [3:0] o_xnor4,   // $reduce_xnor y_width=4  (broken before fix)
    output wire       o_and1,    // $reduce_and  y_width=1  (control: must be unchanged)
    output wire       o_or1,     // $reduce_or   y_width=1  (control: must be unchanged)
    output wire       o_xor1,    // $reduce_xor  y_width=1  (control: must be unchanged)
    output wire       o_xnor1    // $reduce_xnor y_width=1  (control: must be unchanged)
);
    assign o_and4  = &vec_a;    // $reduce_and  Y_WIDTH=4
    assign o_or4   = |vec_a;    // $reduce_or   Y_WIDTH=4
    assign o_xor4  = ^vec_a;    // $reduce_xor  Y_WIDTH=4
    assign o_xnor4 = ~^vec_a;   // $reduce_xnor Y_WIDTH=4

    assign o_and1  = &vec_b;    // $reduce_and  Y_WIDTH=1 -- different input
    assign o_or1   = |vec_b;    // $reduce_or   Y_WIDTH=1 -- different input
    assign o_xor1  = ^vec_b;    // $reduce_xor  Y_WIDTH=1 -- different input
    assign o_xnor1 = ~^vec_b;   // $reduce_xnor Y_WIDTH=1 -- different input
endmodule
