// vim: ts=4: 
/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_fpga_io(
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // All output pins must be assigned. If not used, assign to 0.
  assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
  //assign uio_out = 0;
  //assign uio_oe  = 0;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, clk, rst_n, 1'b0};

  // Integrate the eFGPA

  //Config related ports
  wire config_strobe;
  wire [31:0] config_data;

  // tie off undriven I/O 
	assign uio_out[7:4] = 0;
	assign uio_oe[7:4] = 0;

	// invert iob
	wire [3:0] uio_oeb;
	assign uio_oe[3:0] = ~uio_oeb;

    // efpga fabric's user_design's data port
   	wire [31:0] efpga_din, efpga_dout;
`define EMU_UART
`ifdef EMU_UART
  	micro_uart i_uart (
    	.clk,
    	.io_in(  uio_in[3:0] ),
    	.io_out( uio_out[3:0] ),
    	.io_oeb( uio_oeb[3:0] ),
        .port_din(  efpga_din ),
    	.port_dout( efpga_dout )
	);
`else // eFPGA
  my_eFPGA_top i_efpga (
        //External IO port (dunno what this means)
        .A_config_C		( ),
        .B_config_C		( ),
        .Config_accessC ( ),
		// Actual I/O ports from the fabric
        .I_top			( uio_out[3:0] ),
        .O_top			( uio_in[3:0]  ),
        .T_top			( uio_oeb[3:0] ),
        // System
        .CLK			( clk ),
        .resetn			( rst_n ),
		// Parallel config (Use this)
        .SelfWriteStrobe( config_strobe ),
        .SelfWriteData	( config_data ),
		// Rs232 config n/a
        .Rx				( 1'b0 ),
        .ComActive		( ),
        .ReceiveLED		( ),
		// bitbang n/a
        .s_clk			( 1'b0 ),
        .s_data			( 1'b0 ),
		// Backdoor
    	.bd0_din(  efpga_din ),
    	.bd0_dout( efpga_dout ),
    	.bd0_radr( ),
    	.bd0_wadr( )
	);
`endif // EMU

	// Integrate a SPI logic

	// Itegrate a ratio pwm (CMD=1, N[15:0], D[15:0])
	wire pwm;
	reg [15:0] num, den;
	recip_pwm #( 16 ) i_pwm0 ( clk, !rst_n, num, den, pwm );

endmodule
