// vim: ts=4:
// ratio PWM module
// produces pwm pulses at the ratio of N / D

module recip_pwm #(
    parameter W = 16   // bit-width of numerator/denominator
)(
    input  wire         clk,
    input  wire         rst,
    input  wire [W-1:0] n,
    input  wire [W-1:0] d,
    output reg          pwm
);

    reg [W-1:0] acc;

    always @(posedge clk) begin
        if (rst) begin
            acc <= 0;
            pwm <= 0;
        end else begin
            // accumulate numerator
			acc <= ( acc >= d ) ? acc - d + n : acc + n;
			pwm <= ( acc >= d ) ? 1'b1 : 1'b0;
        end
    end

endmodule
