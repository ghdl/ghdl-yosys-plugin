`default_nettype none
module tb_formal_top #(
	parameter no_backpressure = 0
) (
	input wire clk,
	input wire aresetn,

	input wire [31:0] s_axis_tdata,
	input wire s_axis_tlast,
	input wire s_axis_tvalid,
	output wire s_axis_tready,

	output wire [31:0] m_axis_tdata,
	output wire m_axis_tlast,
	output wire m_axis_tvalid,
	input wire m_axis_tready,

	output wire signed [31:0] discrepancy
);

	reg [31:0] input_byte_count;
	reg [31:0] output_byte_count;
	//reg [0+0-1:0] input_routecheck;
	//reg [0+0-1:0] output_routecheck;

	reg f_past_valid;
	wire signed [31:0] byte_count_discrepancy;
	reg packet_end;

faxis_slave #(
	.F_MAX_PACKET(0),
	.F_MIN_PACKET(0),
	.F_MAX_STALL(0),
	.C_S_AXI_DATA_WIDTH(32),
	.C_S_AXI_ID_WIDTH(0),
	.C_S_AXI_ADDR_WIDTH(0),
	.C_S_AXI_USER_WIDTH(0),
	.OPT_ASYNC_RESET(1'b0)
) axis_slave_formal_properties (
	.i_aclk(clk),
	.i_aresetn(aresetn),
	.i_tvalid(s_axis_tvalid),
	.i_tready(s_axis_tready),
	.i_tdata(s_axis_tdata),
	.i_tlast(s_axis_tlast),
	.f_bytecount(input_byte_count)
	//.f_routecheck(input_routecheck)
);

faxis_master #(
	.F_MAX_PACKET(0),
	.F_MIN_PACKET(0),
	.F_MAX_STALL(0),
	.C_S_AXI_DATA_WIDTH(32),
	.C_S_AXI_ID_WIDTH(0),
	.C_S_AXI_ADDR_WIDTH(0),
	.C_S_AXI_USER_WIDTH(0),
	.OPT_ASYNC_RESET(1'b0)
) axis_master_formal_properties (
	.i_aclk(clk),
	.i_aresetn(aresetn),
	.i_tvalid(m_axis_tvalid),
	.i_tready(m_axis_tready),
	.i_tdata(m_axis_tdata),
	.i_tlast(m_axis_tlast),
	.f_bytecount(output_byte_count)
	//.f_routecheck(output_routecheck)
);

axis_squarer axis_dut (
	.clk(clk),
	.aresetn(aresetn),
	.s_axis_tdata(s_axis_tdata),
	.s_axis_tvalid(s_axis_tvalid),
	.s_axis_tready(s_axis_tready),
	.s_axis_tlast(s_axis_tlast),
	.m_axis_tdata(m_axis_tdata),
	.m_axis_tvalid(m_axis_tvalid),
	.m_axis_tready(m_axis_tready),
	.m_axis_tlast(m_axis_tlast)
);

// f_past_valid is used to make certain that temporal assertions
// depending upon past values depend upon *valid* past values.
// It is true for all clocks other than the first clock.
initial	f_past_valid = 1'b0;
always @(posedge clk)
	f_past_valid <= 1'b1;

always @(*)
begin
	assert(input_byte_count%4==0);
	assert(output_byte_count%4==0);
	byte_count_discrepancy = input_byte_count-output_byte_count;
	discrepancy <= byte_count_discrepancy;
	assume(input_byte_count<=32'h7fffffff);
	assert(output_byte_count<=32'h20);
	if (aresetn == 1) begin
		//assert(byte_count_discrepancy>=-36);
		/*assert(byte_count_discrepancy%32 == 0
			|| byte_count_discrepancy%32 == 4
			|| byte_count_discrepancy%32 == -4);*/
	end
	// Hints below are only for the cover property
	//assume(aresetn == f_past_valid);
	//assume(s_axis_tvalid == 1'b1);
	//assume(m_axis_tready == 1'b1);
	//assume(input_byte_count & 32'hFFFF0000 == 0);
	//cover(byte_count_discrepancy < -4);
	//cover(output_byte_count==16);
end

always @(posedge clk)
begin
	if (f_past_valid && $past(aresetn)==1 && aresetn ==1) begin
		if ($past(s_axis_tvalid) == 1'b1 && $past(s_axis_tready) == 1'b1) begin
			assert(m_axis_tvalid == 1'b1);
			assert(~$past(s_axis_tdata)==m_axis_tdata);
		end
	end
	if (no_backpressure==1) begin
		assume(m_axis_tready==1);
		assume(s_axis_tlast==0);
	end
	cover(f_past_valid && $past(aresetn)==1 && aresetn==1
		&& $past(s_axis_tready)==1'b0 && $past(m_axis_tvalid)==1'b0
		&& s_axis_tready==1'b1 && m_axis_tvalid==1'b0);
	//cover(output_byte_count==16'h10);
end

endmodule
