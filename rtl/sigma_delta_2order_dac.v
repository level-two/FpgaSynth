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
 
    localparam signed [18:0] PLUS1  = 19'h10000;
    localparam signed [18:0] MINUS1 = 19'h70000;

    reg signed [18:0] integr1;
    reg signed [18:0] integr2;

    wire signed [18:0] d_in = { din[17], din[17:0] };

    wire cmp_pos = ~integr2[18];

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            integr1 <= {19{1'b0}};
            integr2 <= {19{1'b0}};
            dout    <= 1'b0;
        end
        else begin
            integr1 <= d_in    + (integr1 + (cmp_pos ? MINUS1 : PLUS1));
            integr2 <= integr1 + (integr2 + (cmp_pos ? MINUS1 : PLUS1));
            dout    <= cmp_pos;
        end
    end
endmodule
