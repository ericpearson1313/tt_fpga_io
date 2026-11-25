`default_nettype none


module top_wrapper;

    wire [3:0] io_in, io_out, io_oeb;
    (* keep, BEL="X0Y1.A" *) IO_1_bidirectional_frame_config_pass io7_i (
        .O(io_in[3]),
        .I(io_out[3]),
        .T(io_oeb[3])
    );
    (* keep, BEL="X0Y1.B" *) IO_1_bidirectional_frame_config_pass io6_i (
        .O(io_in[2]),
        .I(io_out[2]),
        .T(io_oeb[2])
    );
    (* keep, BEL="X0Y2.A" *) IO_1_bidirectional_frame_config_pass io5_i (
        .O(io_in[1]),
        .I(io_out[1]),
        .T(io_oeb[1])
    );
    (* keep, BEL="X0Y2.B" *) IO_1_bidirectional_frame_config_pass io4_i (
        .O(io_in[0]),
        .I(io_out[0]),
        .T(io_oeb[0])
    );

    wire clk;
    (* keep *) Global_Clock clk_i (.CLK(clk));

    micro_uart top_i (
    //sequential_16bit_en top_i (
        .clk(clk),
        .io_in(io_in),
        .io_out(io_out),
        .io_oeb(io_oeb)
    );

endmodule

module bram	#(
        parameter LOC = 0,
        parameter IN_REG = 1'b0,
        parameter OUT_REG = 1'b0,
        localparam DEV_HEIGHT = 2,
        localparam BRAM_X = 3,
    ) (
        input clk,
        input [7:0] waddr, raddr, cfg,
        input [31:0] wdata,
        output [31:0] rdata
    );

    localparam [5:0]x = BRAM_X;
    localparam y0 = (DEV_HEIGHT - 2*LOC);
    localparam y1  = (DEV_HEIGHT - 2*LOC) - 1;

(* keep, BEL=$sformatf("X%0dY%0d.FAB2RAM_A1", x, y0) *) OutPass4_frame_config_mux op0_i (.CLK(clk), .I3(raddr[0]), .I2(raddr[1]), .I1(raddr[2]), .I0(raddr[3]));
(* keep, BEL=$sformatf("X%0dY%0d.FAB2RAM_A0", x, y0) *) OutPass4_frame_config_mux op1_i (.CLK(clk), .I3(raddr[4]), .I2(raddr[5]), .I1(raddr[6]), .I0(raddr[7]));
(* keep, BEL=$sformatf("X%0dY%0d.FAB2RAM_A1", x, y1) *) OutPass4_frame_config_mux op2_i  (.CLK(clk), .I3(waddr[0]), .I2(waddr[1]), .I1(waddr[2]), .I0(waddr[3]));
(* keep, BEL=$sformatf("X%0dY%0d.FAB2RAM_A0", x, y1) *) OutPass4_frame_config_mux op3_i  (.CLK(clk), .I3(waddr[4]), .I2(waddr[5]), .I1(waddr[6]), .I0(waddr[7]));
(* keep, BEL=$sformatf("X%0dY%0d.FAB2RAM_D3", x, y0) *) OutPass4_frame_config_mux op4_i  (.CLK(clk), .I3(wdata[0]), .I2(wdata[1]), .I1(wdata[2]), .I0(wdata[3]));
(* keep, BEL=$sformatf("X%0dY%0d.RAM2FAB_D3", x, y0) *) InPass4_frame_config_mux ip5_i   (.CLK(clk), .O3(rdata[0]), .O2(rdata[1]), .O1(rdata[2]), .O0(rdata[3]));
(* keep, BEL=$sformatf("X%0dY%0d.FAB2RAM_D2", x, y0) *) OutPass4_frame_config_mux op6_i  (.CLK(clk), .I3(wdata[4]), .I2(wdata[5]), .I1(wdata[6]), .I0(wdata[7]));
(* keep, BEL=$sformatf("X%0dY%0d.RAM2FAB_D2", x, y0) *) InPass4_frame_config_mux ip7_i   (.CLK(clk), .O3(rdata[4]), .O2(rdata[5]), .O1(rdata[6]), .O0(rdata[7]));
(* keep, BEL=$sformatf("X%0dY%0d.FAB2RAM_D1", x, y0) *) OutPass4_frame_config_mux op8_i  (.CLK(clk), .I3(wdata[8]), .I2(wdata[9]), .I1(wdata[10]), .I0(wdata[11]));
(* keep, BEL=$sformatf("X%0dY%0d.RAM2FAB_D1", x, y0) *) InPass4_frame_config_mux ip9_i   (.CLK(clk), .O3(rdata[8]), .O2(rdata[9]), .O1(rdata[10]), .O0(rdata[11]));
(* keep, BEL=$sformatf("X%0dY%0d.FAB2RAM_D0", x, y0) *) OutPass4_frame_config_mux op10_i (.CLK(clk), .I3(wdata[12]), .I2(wdata[13]), .I1(wdata[14]), .I0(wdata[15]));
(* keep, BEL=$sformatf("X%0dY%0d.RAM2FAB_D0", x, y0) *) InPass4_frame_config_mux ip11_i  (.CLK(clk), .O3(rdata[12]), .O2(rdata[13]), .O1(rdata[14]), .O0(rdata[15]));
(* keep, BEL=$sformatf("X%0dY%0d.FAB2RAM_D3", x, y1) *) OutPass4_frame_config_mux op12_i (.CLK(clk), .I3(wdata[16]), .I2(wdata[17]), .I1(wdata[18]), .I0(wdata[19]));
(* keep, BEL=$sformatf("X%0dY%0d.RAM2FAB_D3", x, y1) *) InPass4_frame_config_mux ip13_i  (.CLK(clk), .O3(rdata[16]), .O2(rdata[17]), .O1(rdata[18]), .O0(rdata[19]));
(* keep, BEL=$sformatf("X%0dY%0d.FAB2RAM_D2", x, y1) *) OutPass4_frame_config_mux op14_i (.CLK(clk), .I3(wdata[20]), .I2(wdata[21]), .I1(wdata[22]), .I0(wdata[23]));
(* keep, BEL=$sformatf("X%0dY%0d.RAM2FAB_D2", x, y1) *) InPass4_frame_config_mux ip15_i  (.CLK(clk), .O3(rdata[20]), .O2(rdata[21]), .O1(rdata[22]), .O0(rdata[23]));
(* keep, BEL=$sformatf("X%0dY%0d.FAB2RAM_D1", x, y1) *) OutPass4_frame_config_mux op16_i (.CLK(clk), .I3(wdata[24]), .I2(wdata[25]), .I1(wdata[26]), .I0(wdata[27]));
(* keep, BEL=$sformatf("X%0dY%0d.RAM2FAB_D1", x, y1) *) InPass4_frame_config_mux ip17_i  (.CLK(clk), .O3(rdata[24]), .O2(rdata[25]), .O1(rdata[26]), .O0(rdata[27]));
(* keep, BEL=$sformatf("X%0dY%0d.FAB2RAM_D0", x, y1) *) OutPass4_frame_config_mux op18_i (.CLK(clk), .I3(wdata[28]), .I2(wdata[29]), .I1(wdata[30]), .I0(wdata[31]));
(* keep, BEL=$sformatf("X%0dY%0d.RAM2FAB_D0", x, y1) *) InPass4_frame_config_mux ip19_i  (.CLK(clk), .O3(rdata[28]), .O2(rdata[29]), .O1(rdata[30]), .O0(rdata[31]));
(* keep, BEL=$sformatf("X%0dY%0d.FAB2RAM_C" , x, y0) *) OutPass4_frame_config_mux op20_i (.CLK(clk), .I3(cfg[0]), .I2(cfg[1]), .I1(cfg[2]), .I0(cfg[3]));
(* keep, BEL=$sformatf("X%0dY%0d.FAB2RAM_C" , x, y1) *) OutPass4_frame_config_mux op21_i (.CLK(clk), .I3(cfg[4]), .I2(cfg[5]), .I1(cfg[6]), .I0(cfg[7]));

endmodule
`resetall
