// vim: ts=4: 
`default_nettype none

`define EMU_UART

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
	wire reset;

	// Connect up eFPGA's real I/O
    wire rx; // rs232 rx input
    assign rx = io_in[0];
    assign io_out = { 2'b00, rx, 1'b0 }; // loopback rx
    assign io_oeb = { 4'b1001 }; // output disable Rx

`ifdef ORIGINAL 
    // metastable
    reg [1:0] cc;
    always @(posedge clk)
		cc[1:0] <= ( reset ) ? 2'b11 : { cc[0], rx };

	// external provided baud rate enable
	reg baudx8;

	// Delay 
    reg del;
    always @(posedge clk) 
		del <= ( reset ) ? 1'b1 : ( baudx8 ) ? cc[1] : del;

	// Filtered
    reg rxf;
    always @(posedge clk)
		rxf <= ( reset ) ? 1'b1 : ( baudx8 && !del && !cc[1] ) ? 1'b0 : ( baudx8 && del && cc[1] ) ? 1'b1 : rxf;

    // Falling Edge flag for start bit detection
    wire fall; 
    assign fall = ( reset ) ? 1'b0 : ( rxf && !del && !cc[1] ) ? 1'b1 : 1'b0;
`else // Rx is externally registered/filtered/syncrromous with clock.A
	// baudx8 from teh port_din[31];
	reg baudx8;

	// input sampling and falling edge det
    reg rxf;
    always @(posedge clk) 
		rxf <= ( reset ) ? 1'b1 : ( baudx8 ) ? rx : rxf;
    wire fall;
	assign fall = rxf & !rx & baudx8;
`endif

    // counter
    reg [6:0] count; // from -14 to 56, with sampels at 0, 8, ... 56.
	// if -13 don't count until fall, else count until 56 teh -13
    always @(posedge clk)
		count <= 	( reset ) ? -13 : 
				    ( count[6:2] == 5'b11100 && !fall || !baudx8         ) ? count  	:
					( count[6:2] == 5'b11100 &&  fall || count[6:3] != 7 ) ? count+1  : -13;

    // sample at 2, 4, 6, ... 16
	wire sample;
    assign sample = ( baudx8 && !count[6] && count[2:0] == 0 ) ? 1'b1 : 1'b0;

	// generated from last sample
	wire last;
	assign last = ( baudx8 && count[6:3] == 7 ) ? 1'b1 : 1'b0;

    // Uart Data reg
    reg [7:0] data_reg;
	initial data_reg = 0;
    always @(posedge clk) 
		data_reg <= ( reset ) ? 0 : ( sample ) ? { rxf, data_reg[7:1] } : data_reg;

	// The bram is our conestion to the asic

`ifndef EMU_UART // only use the Bram backdoor inside teh FABric
	wire [31:0] port_dout;  // efgpa output wires
	wire [31:0] port_din;   // efgpa input wires
	(* keep *) bram #(
    	    .LOC(0)
	) ram0 (
    	    .clk(clk),
    	    .waddr( 8'hAB ),
    	    .raddr( 8'hCD ),
    	    .cfg  ( 8'b00010000),
    	    .wdata( port_dout ),
    	    .rdata( port_din  )
	);
`endif

	assign port_dout[31:16] = 16'hABCD;
	assign port_dout[15:8] = { rxf, data_reg[7:1] };
	assign port_dout[7:1]  = 0;
	assign port_dout[0]    = last; // write the word to the mailbox

	// connect up baud rate input
    always @(posedge clk)
		baudx8 <= port_din[31];
	assign reset = port_din[30];
	// Connect up swap strobe from asic
	wire swap_strobe;
	assign swap_strobe = port_din[0];

endmodule
`resetall
