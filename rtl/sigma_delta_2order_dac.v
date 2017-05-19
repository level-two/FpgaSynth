// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: sigma_delta_2order_dac.v
// Description: First order sigma-delta dac for audio output
// -----------------------------------------------------------------------------

module sigma_delta_2order_dac #(parameter NBITS = 2, parameter MBITS = 16)
(
    input              clk,
    input              reset,
    input signed [TOT_BITS-1:0] din,
    output reg         dout
);
 
    localparam TOT_BITS = NBITS + MBITS; 
    localparam signed [TOT_BITS-1:0] PLUS1  = { {NBITS-1{1'b0}}, 1'b1, {MBITS{1'b0}} };
    localparam signed [TOT_BITS-1:0] MINUS1 = -PLUS1;

    reg signed [TOT_BITS-1:0] integr1;
    reg signed [TOT_BITS-1:0] integr2;
    wire sign = integr2[TOT_BITS-1];

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            integr1 <= {TOT_BITS{1'b0}};
            integr2 <= {TOT_BITS{1'b0}};
            dout    <= 1'b0;
        end
        else begin
            integr1 <= din     + (integr1 - (sign ? MINUS1 : PLUS1));
            integr2 <= integr1 + (integr2 - (sign ? MINUS1 : PLUS1));
            dout    <= (sign ? 1'b0 : 1'b1);
        end
    end
endmodule
