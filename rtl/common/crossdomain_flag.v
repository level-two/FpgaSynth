// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: crossdomain_flag.v
// Description: Block for crossing flag from one clk domain to another
// -----------------------------------------------------------------------------


module crossdomain_flag (
    input         reset,
    input         clk_a,
    input         clk_b,
    input         flag_domain_a,
    output        flag_domain_b
);

    reg flag_toggle_domain_a;
    always @(posedge reset or posedge clk_a) begin
        if (reset) 
            flag_toggle_domain_a <= 1'b0;
        else
            flag_toggle_domain_a <= flag_toggle_domain_a ^ flag_domain_a;
    end


    reg [2:0] flag_domain_b_reg;
    always @(posedge reset or posedge clk_b) begin
        if (reset) 
            flag_domain_b_reg <= 3'b0;
        else
            flag_domain_b_reg <= {flag_domain_b_reg[1:0], flag_toggle_domain_a};
    end


    assign flag_domain_b = (flag_domain_b_reg[2] ^ flag_domain_b_reg[1]);

endmodule
