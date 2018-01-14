// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: crossdomain_flag_busy.v
// Description: Block for crossing flag from one clk domain to another with
// busy indicator
// -----------------------------------------------------------------------------


module crossdomain_flag_busy (
    input         reset,
    input         clk_a,
    input         flag_domain_a,
    output        busy_a,

    input         clk_b,
    output        flag_domain_b
);

    reg flag_toggle_domain_a;
    always @(posedge reset or posedge clk_a) begin
        if (reset) 
            flag_toggle_domain_a <= 1'b0;
        else
            flag_toggle_domain_a <= flag_toggle_domain_a ^
                                    (flag_domain_a & ~busy_a);
    end


    reg [2:0] flag_a_domain_b;
    always @(posedge reset or posedge clk_b) begin
        if (reset) 
            flag_a_domain_b <= 3'b0;
        else
            flag_a_domain_b <= {flag_a_domain_b[1:0], flag_toggle_domain_a};
    end

    reg [1:0] flag_b_domain_a;
    always @(posedge reset or posedge clk_a) begin
        if (reset) 
            flag_b_domain_a <= 2'b0;
        else
            flag_b_domain_a <= {flag_b_domain_a[0], flag_a_domain_b[2]};
    end

    assign flag_domain_b = (flag_a_domain_b[2] ^ flag_a_domain_b[1]);

    assign busy_a = flag_toggle_domain_a ^ flag_b_domain_a[1];
endmodule
