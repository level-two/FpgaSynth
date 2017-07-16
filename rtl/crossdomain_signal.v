// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: crossdomain_signal.v
// Description: Block for crossing signal from one clk domain to another
// -----------------------------------------------------------------------------


module crossdomain_signal (
    input         reset,
//    input         clk_a,
    input         clk_b,
    input         sig_domain_a,
    output        sig_domain_b
);

    reg [1:0] sig_domain_b_reg;
    always @(posedge reset or posedge clk_b) begin
        if (reset) begin
            sig_domain_b_reg <= 2'b0;
        end
        else begin
            sig_domain_b_reg[1:0] <= { sig_domain_b_reg[0], sig_domain_a };
        end
    end

    assign sig_domain_b = sig_domain_b_reg[1];

endmodule
