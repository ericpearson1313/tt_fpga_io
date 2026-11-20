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
`resetall
