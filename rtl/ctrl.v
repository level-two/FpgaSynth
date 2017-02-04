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

    output reg    gen_left_sample,
    output reg    gen_right_sample
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
            gen_left_sample  <= 0;
            gen_right_sample <= 0;
            chnl             <= 0;
        end
        else if (cnt == 0) begin
            gen_left_sample  <= (chnl == 0) ? 1'b1 : 1'b0;
            gen_right_sample <= (chnl == 1) ? 1'b1 : 1'b0;
            chnl             <= ~chnl;
        end
        else begin
            gen_left_sample  <= 0;
            gen_right_sample <= 0;
        end
    end
endmodule
