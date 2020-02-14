// Wrapper for specific instantiation of EHXPLLL
//
// This is a workaround until we can automatically pass generics to
// instanced vendor primitives (black boxes)
//
module ehxplll_4_5_6_30_15_10_5_29_14_9_0_0_0_0_0_0_0_200_df43956727cb406e91ea03c3249c0f9d5327137e(clki, clkfb, phasesel1, phasesel0, phasedir, phasestep, phaseloadreg, stdby, 
   pllwakesync, rst, enclkop, enclkos, enclkos2, enclkos3, 
   clkop, clkos, clkos2, clkos3, lock, intlock, 
   refclk, clkintfb );

input  clki, clkfb, phasesel1, phasesel0, phasedir, phasestep;
input  phaseloadreg, stdby, pllwakesync, rst;
input  enclkop, enclkos, enclkos2, enclkos3;
output clkop, clkos, clkos2, clkos3, lock, intlock, refclk;
output clkintfb;

	wire clkop_int;

EHXPLLL #(
        .PLLRST_ENA("DISABLED"),
        .INTFB_WAKE("DISABLED"),
        .STDBY_ENABLE("DISABLED"),
        .DPHASE_SOURCE("DISABLED"),
        .OUTDIVIDER_MUXA("DIVA"),
        .OUTDIVIDER_MUXB("DIVB"),
        .OUTDIVIDER_MUXC("DIVC"),
        .OUTDIVIDER_MUXD("DIVD"),
        .CLKI_DIV(4),
        .CLKOP_ENABLE("ENABLED"),
        .CLKOP_DIV(6),
        .CLKOP_CPHASE(5),
        .CLKOP_FPHASE(0),
        // .CLKOP_TRIM_DELAY(0),
        .CLKOP_TRIM_POL("FALLING"),
        .CLKOS_ENABLE("ENABLED"),
        .CLKOS_DIV(30),
        .CLKOS_CPHASE(29),
        .CLKOS_FPHASE(0),
        // .CLKOS_TRIM_DELAY(0),
        .CLKOS_TRIM_POL("FALLING"),
        .CLKOS2_ENABLE("ENABLED"),
        .CLKOS2_DIV(15),
        .CLKOS2_CPHASE(14),
        .CLKOS2_FPHASE(0),
        .CLKOS3_ENABLE("ENABLED"),
        .CLKOS3_DIV(10),
        .CLKOS3_CPHASE(9),
        .CLKOS3_FPHASE(0),
        .FEEDBK_PATH("CLKOP"),
        .CLKFB_DIV(5)
    ) pll_i (
        .RST(1'b0),
        .STDBY(1'b0),
        .CLKI(clki),
        .CLKOP(clkop_int),
        .CLKOS(clkos),
        .CLKFB(clkop_int),
        .CLKINTFB(),
        .PHASESEL0(1'b0),
        .PHASESEL1(1'b0),
        .PHASEDIR(1'b1),
        .PHASESTEP(1'b1),
        .PHASELOADREG(1'b1),
        .PLLWAKESYNC(1'b0),
        .ENCLKOP(1'b0),
        .LOCK(lock)
	);

	assign clkop = clkop_int;

endmodule
