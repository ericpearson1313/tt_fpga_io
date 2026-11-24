// vim: ts=4: 
`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

  // Dump the signals to a FST file. You can view it with gtkwave or surfer.
  initial begin
    $dumpfile("tb.fst");
    $dumpvars(0, tb);
  end

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  reg rs232;
  reg spi_clk, spi_ncs, spi_mosi;
  wire spi_miso;
  // Replace tt_um_example with your module name:
  tt_um_fpga_io user_project (
      .ui_in  ({ ui_in[7:3], spi_mosi, spi_ncs, spi_clk }),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in ({uio_in[7:1],rs232}),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );
  assign spi_miso = uo_out[0];

  	// Rs232 stream generator, uio_in[0] into efgpa fabric user design, or micro_uart EMU
	wire [0:127] str;
	assign str = "Test String 123\n";
	wire [6:0] str_idx;
  	reg [4:0] baud_count;
  	reg [7:0] bit_count;
    wire [3:0] bit_pos;
	assign bit_pos = bit_count[3:0] - 1; 
	assign str_idx = { bit_count[7:4], ~bit_pos[2:0] };
    // bit_count[3:0] =    0    1   2   3   4   5   6   7   8   9     10..15
	// 16 baud pattern:  start, b0, b1, b2, b3, b4, b5, b6, b7, stop, {6{idle}}
	reg en_rs232;
	always @(posedge clk) begin
		baud_count <= (!rst_n) ? 0 : ( baud_count == 31 ) ? 0 : baud_count+1;
		bit_count <= ( !rst_n || !en_rs232 ) ? 0 : ( baud_count == 31 ) ? bit_count+1 : bit_count; // just wraps
		rs232 	<= ( bit_count[3:0] == 0 ) ? 0 : // start bitA
					 ( bit_count[3:0] == 9 ) ? 1 : // stop
					 ( bit_count[3:0] >  9 ) ? 1 : // idle
					     			str[str_idx];  // Otherwise a valid bit is ready.
	end


	// SPI clock generator, free run
	reg [1:0] spi_cnt;
	always @(posedge clk)
		spi_cnt <= (!rst_n) ? 0 : spi_cnt + 1;
	assign spi_clk = spi_cnt[1];

	// Now do the configuration flow and SPI generation
	integer fd;
	integer c;    // must be integer so it can hold -1 (EOF)
	integer ii, jj;
	reg [31:0] ch, sreg;

	initial begin
		spi_ncs = 1;
		spi_mosi = 0;
		en_rs232 = 0;
    	fd = $fopen("../fabulous/efpga/user_design/micro_uart.bin", "rb");
    	if (fd == 0) begin
        	$display("ERROR: Cannot open file");
        	$finish;
    	end

		// wait for reset done
		while( !rst_n ) @(posedge clk);

		// wait some clocks
		for( ii = 0; ii < 10; ii = ii + 1 ) @(posedge clk);

		// Align to the SPI clk, falling edge, launch edge
		for( ii = 0; ii < 10; ii = ii + 1 ) @(negedge spi_clk);
		
		////////////////////////
		// Send the CMD=0;
		////////////////////////

		spi_ncs = 0; // start command
		spi_mosi = 0;
		for( ii = 0; ii < 8; ii = ii + 1 ) // First byte 00
			@(negedge spi_clk);
		
		// Now send FPGA config bitstream
		ch = 32'hFAB0FAB1; // magic first config word
		for( ii = 31; ii >= 0; ii = ii - 1 ) begin // msb first
			spi_mosi = ch[ii];
			@(negedge spi_clk);
		end
		// Send the binary data
    	while (1) begin
        	c = $fgetc(fd);
        	if (c == -1)
            	break;      // EOF reached
        	$display("Read byte = %02x", c[7:0]);
			ch = c;
			for( ii = 0; ii < 8; ii = ii + 1 ) begin // msb first
				spi_mosi = ch[7-ii];
				@(negedge spi_clk);
			end
		end
    	$fclose(fd);
		spi_mosi = 0;
		spi_ncs  = 1;
		@(negedge spi_clk);

			
		// wait 10 spi clks idle
		for( ii = 0; ii < 8; ii = ii + 1 ) // First byte 00
			@(negedge spi_clk);

		////////////////////////
		// Send the CMD=1;
		////////////////////////

		spi_mosi = 0;
		spi_ncs  = 0;

		ch = 1; // cmd byte
		for( ii = 7; ii >= 0; ii = ii - 1 ) begin // msb first
			spi_mosi = ch[ii];
			@(negedge spi_clk);
		end

		ch = { 16'd1, 16'd4 }; // pwm ratio control word
		for( ii = 31; ii >= 0; ii = ii - 1 ) begin // msb first
			spi_mosi = ch[ii];
			@(negedge spi_clk);
		end

		spi_mosi = 0;
		spi_ncs  = 1;
		@(negedge spi_clk);
			
		// wait 10 spi clks idle
		for( ii = 0; ii < 8; ii = ii + 1 ) // First byte 00
			@(negedge spi_clk);
		
		////////////////////////
		// Turn on Serial Stream
		////////////////////////

		@(posedge clk);
		en_rs232 = 1; // strt the serial stream
		
		////////////////////////
		// Send the CMD=2 loop;
		////////////////////////

		// wait 10 spi clks idle
		for( ii = 0; ii < 8; ii = ii + 1 ) // First byte 00
			@(negedge spi_clk);

		for( ; ; ) begin // Polling loop
			spi_mosi = 0;
			spi_ncs  = 0;
			ch = 2; // cmd byte
			for( ii = 7; ii >= 0; ii = ii - 1 ) begin // msb first
				spi_mosi = ch[ii];
				@(negedge spi_clk);
			end
			@(negedge spi_clk);
		
			for( ii = 31; ii >= 0; ii = ii - 1 ) begin // msb first
				@(posedge spi_clk); // Rising edge for reading
				sreg[ii] = spi_miso;
			end
			@(negedge spi_clk);
			spi_mosi = 0;
			spi_ncs  = 1;

			if( sreg[0] )
				$display( "%x %x (%c)\n", sreg, sreg[15:8], sreg[15:8] );

			// wait 10 spi clks idle
			for( ii = 0; ii < 8; ii = ii + 1 ) // First byte 00
				@(negedge spi_clk);
		end
			
    end

endmodule
