// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: ctrl.v
// Description: Control block
// -----------------------------------------------------------------------------

module ctrl (
    input         clk,
    input         reset,

    input         spdif_left_accepted,
    input         spdif_right_accepted,

    output reg    gen_left_sample,
    output reg    gen_right_sample,
);

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            gen_left_sample  <= 0;
            gen_right_sample <= 0;
        end
        else begin
            gen_left_sample  <= spdif_right_accepted;
            gen_right_sample <= spdif_left_accepted;
        end
    end
endmodule
