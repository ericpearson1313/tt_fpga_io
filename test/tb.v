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
  // Replace tt_um_example with your module name:
  tt_um_fpga_io user_project (
      .ui_in  (ui_in),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in ({uio_in[7:1],rs232}),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );

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
	always @(posedge clk) begin
		baud_count <= (!rst_n) ? 0 : ( baud_count == 31 ) ? 0 : baud_count+1;
		bit_count <= (!rst_n) ? 0 : ( baud_count == 31 ) ? bit_count+1 : bit_count; // just wraps
		rs232 	<= ( bit_count[3:0] == 0 ) ? 0 : // start bitA
					 ( bit_count[3:0] == 9 ) ? 1 : // stop
					 ( bit_count[3:0] >  9 ) ? 1 : // idle
					     			str[str_idx];  // Otherwise a valid bit is ready.
	end
  

endmodule
