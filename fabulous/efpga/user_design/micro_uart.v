// vim: ts=4: 
`default_nettype none

//`define EMU_UART

module micro_uart (
    input wire clk,
    input wire [3:0] io_in,
    output wire [3:0] io_out,
    output wire [3:0] io_oeb
`ifdef EMU_UART
    ,input wire [31:0] port_din,
	output wire [31:0] port_dout
`endif
);
	// Connect up eFPGA's real I/O
    wire rx; // rs232 rx input
    assign rx = io_in[0];
    assign io_out = { 2'b00, rx, 1'b0 }; // loopback rx
    assign io_oeb = { 4'b1001 }; // output disable Rx

    // metastable
    reg [1:0] cc;
    always @(posedge clk)
		cc[1:0] <= { cc[0], rx };

	// external provided baud rate enable
	reg baudx8;

	// Delay 
    reg del;
    always @(posedge clk) 
		del <= ( baudx8 ) ? cc[1] : del;

	// Filtered
    reg rxf;
    always @(posedge clk)
		rxf <= ( baudx8 && !del && !cc[1] ) ? 1'b0 : ( baudx8 && del && cc[1] ) ? 1'b1 : rxf;

    // Falling Edge flag for start bit detection
    wire fall; 
    assign fall = ( rxf && !del && !cc[1] ) ? 1'b1 : 1'b0;

    // counter
    reg [6:0] count; // from -13 to 56, with sampels at 0, 8, ... 56.
    always @(posedge clk)
		count <= ( !baudx8 ) ? count : ( count[6:2]  == -4 && fall ) ? 1 : ( count[6:3] == 7 ) ? -13 : count + 1;


    // sample at 2, 4, 6, ... 16
	wire sample;
    assign sample = ( baudx8 && !count[6] && count[2:0] == 0 ) ? 1'b1 : 1'b0;

	// generated from last sample
	wire last;
	assign last = ( baudx8 && count == 56 ) ? 1'b1 : 1'b0;

    // Uart Data reg
    reg [7:0] data_reg;
    always @(posedge clk) 
		data_reg <= ( sample ) ? { rxf, data_reg[7:1] } : data_reg;

	// The bram is our conestion to the asic

`ifndef EMU_UART // only use the Bram backdoor inside teh FABric
	wire [31:0] port_dout;  // efgpa output wires
	wire [31:0] port_din;   // efgpa input wires
	(* keep *) bram #(
    	    .LOC(0)
	) ram0 (
    	    .clk(clk),
    	    .waddr( 8'b0 ),
    	    .raddr( 8'b0 ),
    	    .cfg  ( 8'b00010000),
    	    .wdata( port_dout ),
    	    .rdata( port_din  )
	);
`endif

	assign port_dout[31:9] = 0;
	assign port_dout[8:1] = { rxf, data_reg[7:1] };
	assign port_dout[0]   = last; // write the word to the mailbox

	// connect up baud rate input
    always @(posedge clk)
		baudx8 <= port_din[0];

endmodule
`resetall
