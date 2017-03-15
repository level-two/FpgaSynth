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

module ctrl (
    input         clk,
    input         reset,
    output reg    smpl_rate_trig_l,
    output reg    smpl_rate_trig_r
);

    reg [11:0] cnt;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            cnt  <= 0;
        end
        else if (cnt == 12'd1042) begin
            cnt <= 0;
        end
        else begin
            cnt <= cnt + 1;
        end
    end

    reg chnl;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            smpl_rate_trig_l <= 0;
            smpl_rate_trig_r <= 0;
            chnl             <= 0;
        end
        else if (cnt == 0) begin
            smpl_rate_trig_l <= (chnl == 0) ? 1'b1 : 1'b0;
            smpl_rate_trig_r <= (chnl == 1) ? 1'b1 : 1'b0;
            chnl             <= ~chnl;
        end
        else begin
            smpl_rate_trig_l <= 0;
            smpl_rate_trig_r <= 0;
        end
    end
endmodule
