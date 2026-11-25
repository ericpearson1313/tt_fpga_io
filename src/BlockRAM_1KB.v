`default_nettype none

module my_BlockRAM_1KB #(
    // Default 24 means bits wr_data[25:24] will become bits [9:8] of read address
    parameter integer READ_ADDRESS_MSB_FROM_DATA_LSB  = 24,
    // Default 16 means bits wr_data[17:16] will become bits [9:8] of write address
    parameter integer WRITE_ADDRESS_MSB_FROM_DATA_LSB = 16,
    // Default 20 means bit wr_data[20] will become the dynamic write enable input
    parameter integer WRITE_ENABLE_FROM_DATA          = 20
) (
    input  wire        clk    ,
    input  wire [ 7:0] rd_addr,
    output wire [31:0] rd_data,
    input  wire [ 7:0] wr_addr,
    input  wire [31:0] wr_data,
    // Configuration bit inputs
    input  wire        C0     , // C0 and C1 select write port width
    input  wire        C1     ,
    input  wire        C2     , // C2 and C3 select read port width
    input  wire        C3     ,
    input  wire        C4     , // C4 selects the always_write_enable
    input  wire        C5     ,  // C5 selects register bypass
    // Back door bits
    input  wire [31:0] bd_din ,
    output wire [31:0] bd_dout,
    output wire [7:0]  bd_radr,
    output wire [7:0]  bd_wadr
);
    // NOTE: the read enable is currently constantly ON
    // NOTE: the R/W port on the standard cell is used only in write mode
    // NOTE: enable ports on the primitive RAM are active lows
    wire [1:0] rd_port_configuration                  ;
    wire [1:0] wr_port_configuration                  ;
    wire       optional_register_enabled_configuration;
    wire       always_write_enable                    ;
    assign wr_port_configuration                   = {C0, C1};
    assign rd_port_configuration                   = {C2, C3};
    assign always_write_enable                     = C4;
    assign optional_register_enabled_configuration = C5;

    reg mem_write_enable;

    always @(*)
        begin
            if (always_write_enable)
                begin
                    mem_write_enable = 0;  // This RAM primitive is active-low.
                end
            else
                begin
                    // Inverting the bit to make it active-high
                    mem_write_enable = (!(wr_data[WRITE_ENABLE_FROM_DATA]));
                end
        end
    reg [ 3:0] mem_wr_mask  ;
    reg [31:0] muxed_data_in;

    wire [1:0] wr_addr_topbits;

    assign wr_addr_topbits = wr_data[WRITE_ADDRESS_MSB_FROM_DATA_LSB+1:WRITE_ADDRESS_MSB_FROM_DATA_LSB];

    // Write port config -> mask + write data multiplex

    always @(*)
        begin
            muxed_data_in = 32'd0;
            if (wr_port_configuration == 0)
                begin
                    mem_wr_mask   = 4'b1111;
                    muxed_data_in = wr_data;
                end
            else if (wr_port_configuration == 1)
                begin
                    if (wr_addr_topbits == 0)
                        begin
                            mem_wr_mask         = 4'b0011;
                            muxed_data_in[15:0] = wr_data[15:0];
                        end
                    else
                        begin
                            mem_wr_mask          = 4'b1100;
                            muxed_data_in[31:16] = wr_data[15:0];
                        end
                end
            else if (wr_port_configuration == 2)
                begin
                    if (wr_addr_topbits == 0)
                        begin
                            mem_wr_mask        = 4'b0001;
                            muxed_data_in[7:0] = wr_data[7:0];
                        end
                    else if (wr_addr_topbits == 1)
                        begin
                            mem_wr_mask         = 4'b0010;
                            muxed_data_in[15:8] = wr_data[7:0];
                        end
                    else if (wr_addr_topbits == 2)
                        begin
                            mem_wr_mask          = 4'b0100;
                            muxed_data_in[23:16] = wr_data[7:0];
                        end
                    else
                        begin
                            mem_wr_mask          = 4'b1000;
                            muxed_data_in[31:24] = wr_data[7:0];
                        end
                end
            else
                begin
                    mem_wr_mask = 4'b0000;
                end
        end
    wire [31:0] mem_dout;
`ifdef NEVER
    sram_1rw1r_32_256_8_sky130 memory_cell (
        .clk0  (clk             ),
        .csb0  (mem_write_enable),
        .web0  (mem_write_enable),
        .wmask0(mem_wr_mask     ),
        .addr0 (wr_addr[7:0]    ),
        .din0  (muxed_data_in   ),
        /* verilator lint_off PINCONNECTEMPTY */
        .dout0 (                ), // Use separate ports for reading and writing
        /* verilator lint_on PINCONNECTEMPTY */
        .clk1  (clk             ),
        .csb1  (1'b0            ),
        .addr1 (rd_addr[7:0]    ),
        .dout1 (mem_dout        )
    );
`else
	// Top level back door probes to get at address data;
	assign mem_dout[31:16]={ bd_din[16], bd_din[17], bd_din[18], bd_din[19], 
			         bd_din[20], bd_din[21], bd_din[22], bd_din[23], 
			         bd_din[24], bd_din[25], bd_din[26], bd_din[27], 
			         bd_din[28], bd_din[29], bd_din[30], bd_din[31]};
	assign mem_dout[15:00]={ bd_din[00], bd_din[01], bd_din[02], bd_din[03], 
			         bd_din[04], bd_din[05], bd_din[06], bd_din[07], 
			         bd_din[08], bd_din[09], bd_din[10], bd_din[11], 
			         bd_din[12], bd_din[13], bd_din[14], bd_din[15]};
	assign bd_dout[31:16]= { muxed_data_in[16], muxed_data_in[17], muxed_data_in[18], muxed_data_in[19], 
			         muxed_data_in[20], muxed_data_in[21], muxed_data_in[22], muxed_data_in[23], 
			         muxed_data_in[24], muxed_data_in[25], muxed_data_in[26], muxed_data_in[27], 
			         muxed_data_in[28], muxed_data_in[29], muxed_data_in[30], muxed_data_in[31]};
	assign bd_dout[15:00]= { muxed_data_in[00], muxed_data_in[01], muxed_data_in[02], muxed_data_in[03], 
			         muxed_data_in[04], muxed_data_in[05], muxed_data_in[06], muxed_data_in[07], 
			         muxed_data_in[08], muxed_data_in[09], muxed_data_in[10], muxed_data_in[11], 
			         muxed_data_in[12], muxed_data_in[13], muxed_data_in[14], muxed_data_in[15]};
	assign bd_radr[7:0] = { rd_addr[0], rd_addr[1], rd_addr[2], rd_addr[3], rd_addr[4], rd_addr[5], rd_addr[6], rd_addr[7] };
	assign bd_wadr[7:0] = { wr_addr[0], wr_addr[1], wr_addr[2], wr_addr[3], wr_addr[4], wr_addr[5], wr_addr[6], wr_addr[7] };
`endif
    reg [1:0] rd_dout_sel;
    always @(posedge clk)
        begin
            rd_dout_sel <= wr_data[READ_ADDRESS_MSB_FROM_DATA_LSB+1:READ_ADDRESS_MSB_FROM_DATA_LSB];
        end
    reg [31:0] rd_dout_muxed;

    always @(*)
        begin
            rd_dout_muxed[31:0] = mem_dout[31:0];
            if (rd_port_configuration == 0)
                begin
                    rd_dout_muxed[31:0] = mem_dout[31:0];
                end
            else if (rd_port_configuration == 1)
                begin
                    if (rd_dout_sel[0] == 0)
                        begin
                            rd_dout_muxed[15:0] = mem_dout[15:0];
                        end
                    else
                        begin
                            rd_dout_muxed[15:0] = mem_dout[31:16];
                        end
                end
            else if (rd_port_configuration == 2)
                begin
                    if (rd_dout_sel == 0)
                        begin
                            rd_dout_muxed[7:0] = mem_dout[7:0];
                        end
                    else if (rd_dout_sel == 1)
                        begin
                            rd_dout_muxed[7:0] = mem_dout[15:8];
                        end
                    else if (rd_dout_sel == 2)
                        begin
                            rd_dout_muxed[7:0] = mem_dout[23:16];
                        end
                    else
                        begin
                            rd_dout_muxed[7:0] = mem_dout[31:24];
                        end
                end
            else
                begin
                    rd_dout_muxed = mem_dout;
                end
        end
    reg [31:0] rd_dout_additional_register;
    always @(posedge clk)
        begin
            rd_dout_additional_register <= rd_dout_muxed;
        end
    reg [31:0] final_dout;
    assign rd_data = final_dout;

    always @(*)
        begin
            if (optional_register_enabled_configuration)
                begin
                    final_dout = rd_dout_additional_register;
                end
            else
                begin
                    final_dout = rd_dout_muxed;
                end
        end
endmodule
`ifdef NEVER
(* blackbox *)
module sram_1rw1r_32_256_8_sky130 #(
    parameter integer NUM_WMASKS = 4              ,
    parameter integer DATA_WIDTH = 32             ,
    parameter integer ADDR_WIDTH = 8              ,
    parameter integer RAM_DEPTH  = 1 << ADDR_WIDTH,
    // NOTE: This delay is arbitrary.
    parameter integer DELAY      = 3
) (
    // Port 0: RW
    input  wire                  clk0  , // clock
    input  wire                  csb0  , // active low chip select
    input  wire                  web0  , // active low write control
    input  wire [NUM_WMASKS-1:0] wmask0, // write mask
    input  wire [ADDR_WIDTH-1:0] addr0 ,
    input  wire [DATA_WIDTH-1:0] din0  ,
    output wire [DATA_WIDTH-1:0] dout0 ,
    // Port 1: R
    input  wire                  clk1  , // clock
    input  wire                  csb1  , // active low chip select
    input  wire [ADDR_WIDTH-1:0] addr1 ,
    output wire [DATA_WIDTH-1:0] dout1
);
endmodule
`endif
`resetall
