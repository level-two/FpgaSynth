// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: ctrl.v
// Description: Control block. Triggers left and right channels to generate
//              new sample (sample rate is taken to be 48kHz)
// -----------------------------------------------------------------------------

`include "globals.vh"

module ctrl (
    input         clk,
    input         reset,
    output reg    smpl_rate_trig
);

    reg [11:0] cnt;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            cnt  <= 0;
            smpl_rate_trig <= 0;
        end
        else if (cnt == `CLK_DIV_48K-1) begin
            cnt <= 0;
            smpl_rate_trig <= 1'b1;
        end
        else begin
            cnt <= cnt + 1;
            smpl_rate_trig <= 0;
        end
    end
endmodule
