// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: sigma_delta_2order_dac.v
// Description: First order sigma-delta dac for audio output
// -----------------------------------------------------------------------------

module sigma_delta_2order_dac
(
    input               clk,
    input               reset,
    input signed [17:0] din,
    output reg          dout
);
 
    localparam signed [23:0] PLUS1  = 24'h10000;
    localparam signed [23:0] MINUS1 = -PLUS1;

    reg signed [23:0] integr1;
    reg signed [23:0] integr2;

    wire signed [23:0] d_in = { {6{din[17]}}, din[17:0] };

    wire cmp_pos = ~integr2[23];

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            integr1 <= {24{1'b0}};
            integr2 <= {24{1'b0}};
            dout    <= 1'b0;
        end
        else begin : dsp
            reg signed [23:0] v1;
            v1 = d_in + (integr1 + (cmp_pos ? MINUS1 : PLUS1));
            integr1 <= v1;
            integr2 <= v1 + (integr2 + (cmp_pos ? MINUS1 : PLUS1));
            dout    <= cmp_pos;
        end
    end
endmodule
