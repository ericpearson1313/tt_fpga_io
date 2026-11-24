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
  	assign uo_out[7:3]  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
	assign uio_out[7:4] = 0;
	assign uio_oe[7:4] = 0;

  	// List all unused inputs to prevent warnings
  	wire _unused = &{ena, clk, rst_n, 1'b0};

	//////////////////////////////////////////////////
	//
  	// Integrate the eFGPA (or EMUlaed user code)
	//
	//////////////////////////////////////////////////

	// User Leds
	wire config_led;
	wire run_led;
	assign uo_out[1] = config_led;
	assign uo_out[2] = 1; // run_led;
	
  	//Config related ports
  	wire config_strobe;
  	wire [31:0] config_data;

	// invert iob for FAB -> TT
	wire [3:0] uio_oeb;
	assign uio_oe[3:0] = ~uio_oeb;

    // efpga fabric's user_design's data port
   	wire [31:0] efpga_din, efpga_dout;
	reg nrst_config;

`define EMU_UART
`ifdef EMU_UART
  	micro_uart i_uart (
    	.clk,
    	.io_in(  uio_in[3:0] ),
    	.io_out( uio_out[3:0] ),
    	.io_oeb( uio_oeb[3:0] ),
		// emulation only I/O
        .reset    ( !rst_n ),
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
        .resetn			( rst_n & nrst_config ),
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

	//////////////////////////////////////////////////
	//
	// SPI Slave Interface
	//
	//////////////////////////////////////////////////

	wire spi_clk;
	wire spi_ncs;
	wire spi_mosi;
	wire spi_miso;
	
	assign spi_clk = ui_in[0];
	assign spi_ncs = ui_in[1];
	assign spi_mosi= ui_in[2];
	assign uo_out[0] = spi_miso;

	// Metastable spi inputs
	reg [8:0] spi_cc;
	always @(posedge clk) 
		spi_cc <= ( !rst_n ) ? 0 : { spi_cc[5:0], spi_clk, spi_ncs, spi_mosi };

	// glitch filter SPI Inputs
	reg filt_clk, filt_ncs, filt_mosi;
	always @(posedge clk) begin
		filt_clk <= ( !rst_n ) ? 0 : ( spi_cc[8] && spi_cc[5] ) ? 1 : ( !spi_cc[8] && !spi_cc[5] ) ? 0 : filt_clk;
		filt_ncs <= ( !rst_n ) ? 0 : ( spi_cc[7] && spi_cc[4] ) ? 1 : ( !spi_cc[7] && !spi_cc[4] ) ? 0 : filt_ncs;
		filt_mosi<= ( !rst_n ) ? 0 : ( spi_cc[6] && spi_cc[3] ) ? 1 : ( !spi_cc[8] && !spi_cc[3] ) ? 0 : filt_mosi;
	end

	// detect rising, falling spi clk edges
	reg clk_rise, clk_fall; // data sampled on rise and launched on fall
	always @(posedge clk) begin
		clk_fall <= ( !rst_n ) ? 0 : (  filt_clk && !spi_cc[8] && !spi_cc[5] ) ? 1 : 0;
		clk_rise <= ( !rst_n ) ? 0 : ( !filt_clk &&  spi_cc[8] &&  spi_cc[5] ) ? 1 : 0;
	end

	// Bit counter count active bits
	reg [15:0] spi_bitcount;
	always @(posedge clk)
		spi_bitcount <= ( !rst_n ) ? 0 : ( !clk_rise ) ? spi_bitcount : ( !filt_ncs ) ? spi_bitcount + 1 : 0;
	

	// First byte is CMD (msb first)
	reg [7:0] cmd_data;
	always @(posedge clk)
		cmd_data <= ( !rst_n ) ? 0 : ( clk_rise && !filt_ncs && spi_bitcount <= 7 ) ? { cmd_data[6:0], filt_mosi } : cmd_data;
	reg byte_strobe;
	always @(posedge clk)
		byte_strobe <= ( clk_rise && !filt_ncs && spi_bitcount[2:0]  == 7 ) ? 1'b1 : 1'b0;

	
	// turn on config led when loading fpga bitstream
	assign config_led = ( !filt_ncs && cmd_data == 8'b0 && spi_bitcount > 7 ) ? 1'b1 : 1'b0;

	// shift in data upon ncs, and count bits

    // maintain 32 bit input register
	reg [31:0] spi_ireg;
	always @(posedge clk)
		spi_ireg <= ( !rst_n ) ? 0 : ( clk_rise && !filt_ncs && spi_bitcount > 7 ) ? { spi_ireg[30:0], filt_mosi } : spi_ireg;
	wire [31:0] wdata;
	assign wdata = spi_ireg;

	// generate strobe:
	// we_pwm after 5th bute received, where cmd == 1
	// we_fabric after last bit of 5th bute received, where cmd == 2
	// re_fabric before first bit of 2nd byte (ready to shift out) where cmd == 2
    // we_config immediately after last bit of 5th, and 5th+N*4th 
	wire we_config; // write a config word
	wire we_pwm; // laod data into ratio pwm
	wire we_fabric; // load fabric data iin reg
	wire re_fabric; // fabic data out reg will be registered based on en=rd

	assign we_config 	= ( byte_strobe && cmd_data == 8'h00 && spi_bitcount >= 40 && spi_bitcount[4:0] == 8) ? 1'b1 : 1'b0;
	assign we_pwm 		= ( byte_strobe && cmd_data == 8'h01 && spi_bitcount == 40 ) ? 1'b1 : 1'b0;
	assign we_fabric 	= ( byte_strobe && cmd_data == 8'h02 && spi_bitcount == 40 ) ? 1'b1 : 1'b0;
	assign re_fabric    = ( byte_strobe && cmd_data == 8'd02 && spi_bitcount == 8  ) ? 1'b1 : 1'b0;

	always @(posedge clk) 
		nrst_config	<= ( cmd_data == 8'h00 && spi_bitcount >= 16 && spi_bitcount < 24 ) ? 1'b0 : 1'b1;

	//////////////////////////////////////////////////
	// eFPGA config interface
	//////////////////////////////////////////////////
	reg [31:0] config_reg;
	always @(posedge clk) 
		config_reg <= ( !rst_n ) ? 0 : ( we_config ) ? wdata : config_reg;
	assign config_data = config_reg;
	reg [3:0] cyc_cnt;
	always @(posedge clk) 
		cyc_cnt <= ( !rst_n ) ? 0 : ( we_config ) ? 1 : ( cyc_cnt != 0 ) ? cyc_cnt + 1 : cyc_cnt; // 16 cycle seqence
	assign config_strobe = cyc_cnt[3]; // 8 cycles of setup, and 8 cycle strobe for any slow latches.

	//////////////////////////////////////////////////
	// Itegrate a ratio pwm writable register
	//////////////////////////////////////////////////

	wire pwm;
	reg [15:0] num, den;
	always @(posedge clk)
		{ num, den } <= ( !rst_n ) ? { 16'd1, 16'd4 } : ( we_pwm ) ? wdata : { num, den };
	recip_pwm #( 16 ) i_pwm0 ( clk, !rst_n, num, den, pwm );

	//////////////////////////////////////////////////
	// Efabric input and outptu regs and mailbox.
	//////////////////////////////////////////////////

	reg [31:0] efpga_din_reg;
	reg [31:0] efpga_dout_reg;
	always @(posedge clk) begin
		efpga_din_reg[0]     <= we_fabric;
		efpga_din_reg[31:1]  <= ( !rst_n ) ? 0 : ( we_fabric     ) ? wdata : efpga_din_reg[31:1];
		efpga_dout_reg[0]    <= ( !rst_n ) ? 0 : ( efpga_dout[0] ) ? 1 : ( re_fabric ) ? 0 : efpga_dout_reg[0]; // mail flag
		efpga_dout_reg[31:1] <= ( !rst_n ) ? 0 : ( efpga_dout[0] ) ? efpga_dout[31:1] : efpga_dout_reg[31:1];
	end
	assign efpga_din[31:0] = { pwm, efpga_din_reg[30:0] };

	// Connect up a 32 bit output register
	reg [31:0] spi_oreg;
	always @(posedge clk)
		spi_oreg <= ( !rst_n ) ? 0 : ( re_fabric ) ? efpga_dout_reg : ( clk_rise && !filt_ncs ) ? { spi_oreg[30:0], 1'b0 } : spi_oreg;
	// Spi output
	assign spi_miso = spi_oreg[31];

endmodule
