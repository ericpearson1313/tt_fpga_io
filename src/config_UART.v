`default_nettype none

// Tie off for quartus flow. not used.
module config_UART #(
        parameter reg [1:0] Mode = 2'd0,
        // The default mode is "auto", which switches between "hex" and "binary" mode,
        // but takes a bit more logic.
        // Mode "bin" is the faster binary mode, but might not work on all machines/boards.
        // Mode "auto" uses the MSB in the command byte (the 8th byte in the comload header)
        // to set the mode.
        // Below is shown how the modes can be selected:
        // [0:auto|1:hex|2:bin]
        // com_rate = f_CLK / Baudrate (e.g., 25 MHz/115200 Baud = 217)
        parameter [11:0] ComRate = 12'd217
    ) (
        input wire CLK,
        input wire reset_n,
        input wire Rx,
        output reg [31:0] WriteData,
        output wire ComActive,
        output reg WriteStrobe,
        output wire [7:0] Command,
        output reg ReceiveLED
    );

		always @(posedge CLK) begin
			WriteData <= 0;
			WriteStrobe <= 0;
			ReceiveLED <= 0;
		end
		assign ComActive = 0;
		assign Command = 0;
endmodule
`resetall
