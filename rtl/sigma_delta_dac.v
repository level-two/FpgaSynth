// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: sigma_delta_dac.v
// Description: Second order sigma-delta dac for audio output
// -----------------------------------------------------------------------------

module sigma_delta_dac #(parameter NBITS = 2, parameter MBITS = 16)
(
    input              clk,
    input              reset,
    input signed [TOT_BITS-1:0] din,
    output reg         dout
);
 
    localparam TOT_BITS = NBITS + MBITS; 

    reg signed [TOT_BITS-1:0] del1;
    reg signed [TOT_BITS-1:0] del2;
    reg signed [TOT_BITS-1:0] d_q;

    localparam signed [TOT_BITS-1:0] c1   = { {NBITS-1{1'b0}}, 1'b1, {MBITS{1'b0}} };
    localparam signed [TOT_BITS-1:0] c_1  = -c1;

    /*
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            del1 <= 0;
            del2 <= 0;
            d_q  <= 0;
            dout <= 0;
        end
        else begin : dac
            // note that sign before d_q is changed to plus!
            // thus constants loaded to d_q are also with opposite signs
            reg signed [TOT_BITS-1:0] v1;
            reg signed [TOT_BITS-1:0] v2;
            v1 = din + d_q + del1;
            v2 = v1  + d_q + del2;
            // if (v2 > 0) begin
            if (v2[TOT_BITS-1] == 1'b0) begin
                d_q  <= c_1; // -1.0
                dout <= 1'b1;
            end
            else begin
                d_q  <= c1;  // +1.0
                dout <= 1'b0;
            end
            del1 <= v1;
            del2 <= v2;
        end
    end
    */

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            del1 <= 0;
            d_q  <= 0;
            dout <= 0;
        end
        else begin : dac
            // note that sign before d_q is changed to plus!
            // thus constants loaded to d_q are also with opposite signs
            reg signed [TOT_BITS-1:0] v1;
            v1 = din + d_q + del1;
            // if (v2 > 0) begin
            if (v1[TOT_BITS-1] == 1'b0) begin
                d_q  <= c_1; // -1.0
                dout <= 1'b1;
            end
            else begin
                d_q  <= c1;  // +1.0
                dout <= 1'b0;
            end
            del1 <= v1;
        end
    end
endmodule
