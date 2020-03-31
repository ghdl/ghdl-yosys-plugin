// Workaround BRAM implementation for fifo buffer
// 2020 <hackfin@section5.ch>

module bram_2psync #(
	parameter DATA = 8,
	parameter ADDR = 6
) (

	// Port A
	input	wire				clk,
	input	wire				a_we,
	input	wire	[ADDR-1:0]	a_addr,
	input	wire	[DATA-1:0]	a_write,
	output	reg		[DATA-1:0]	a_read,

	// Port B
	input	wire				b_we,
	input	wire	[ADDR-1:0]	b_addr,
	input	wire	[DATA-1:0]	b_write,
	output	reg		[DATA-1:0]	b_read
);

// Shared memory
reg [DATA-1:0] mem [(2**ADDR)-1:0];

reg [ADDR-1:0] addr_b;
reg [ADDR-1:0] addr_a;


assign a_read = mem[addr_a];
// assign b_read = mem[addr_b];

always @(posedge clk) begin: DUAL_RAW_PORT_A_PROC
    addr_a <= a_addr;
end


always @(posedge clk) begin: DUAL_RAW_PORT_B_PROC
    addr_b <= b_addr;
    if (b_we) begin
        mem[b_addr] <= b_write;
    end
end


endmodule
