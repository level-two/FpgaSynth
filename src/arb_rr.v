// -----------------------------------------------------------------------------
// Copyright (C) 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: arb_rr.v
// Description: Simple round-robin arbiter
// -----------------------------------------------------------------------------

module arb_rr #(parameter PORTS_NUM = 4)
(
    input reset,
    input clk,

    input  [PORTS_NUM-1:0] req,
    output [PORTS_NUM-1:0] gnt
);

    reg [PORTS_NUM-1:0] rr_cnt;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rr_cnt <= 1;
        end
        else begin
            if (gnt == 0) begin
                rr_cnt <= {rr_cnt[PORTS_NUM-2:0], rr_cnt[PORTS_NUM-1]};
            end
        end
    end

    assign gnt = req & rr_cnt;
endmodule
