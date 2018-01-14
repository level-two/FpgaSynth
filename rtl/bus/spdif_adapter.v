// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: spdif_adapter.v
// Description: Adapter for spdif module for crossing between clock domains
// -----------------------------------------------------------------------------

`include "globals.vh"

module spdif_adapter (
    input        clk,
    input        clk_6p140M,
    input        reset,

    input [15:0] right_sample,
    input        right_sample_stb,
    output       right_sample_done,
    output       right_accepted,

    input [15:0] left_sample,
    input        left_sample_stb,
    output       left_sample_done,
    output       left_accepted,

    output       spdif_out
);

    wire [15:0] spdif_right_sample;
    wire [15:0] spdif_left_sample;
    
    crossdomain_data #(16) crsdom_smpl_right
    (
        .reset(reset),
        .clk_a(clk),
        .data_a(right_sample),
        .data_stb_a(right_sample_stb),
        .done_a(right_sample_done),

        .clk_b(clk_6p140M),
        .data_b(spdif_right_sample),
        .data_stb_b(spdif_right_sample_stb)
    );

    
    crossdomain_data #(16) crsdom_smpl_left
    (
        .reset(reset),
        .clk_a(clk),
        .data_a(left_sample),
        .data_stb_a(left_sample_stb),
        .done_a(left_sample_done),

        .clk_b(clk_6p140M),
        .data_b(spdif_left_sample),
        .data_stb_b(spdif_left_sample_stb)
    );


    reg [15:0] spdif_right_sample_reg;
    always @(posedge reset or posedge clk_6p140M) begin
        if (reset) begin
            spdif_right_sample_reg <= 0;
        end
        else if (spdif_right_sample_stb) begin
            spdif_right_sample_reg <= spdif_right_sample;
        end
    end


    reg [15:0] spdif_left_sample_reg;
    always @(posedge reset or posedge clk_6p140M) begin
        if (reset) begin
            spdif_left_sample_reg <= 0;
        end
        else if (spdif_left_sample_stb) begin
            spdif_left_sample_reg <= spdif_left_sample;
        end
    end


    wire spdif_left_accepted;
    wire spdif_right_accepted;


    spdif spdif (
        .clk(clk_6p140M),
        .reset(reset),
        .left_in(spdif_left_sample_reg),
        .right_in(spdif_right_sample_reg),
        .left_accepted(spdif_left_accepted),
        .right_accepted(spdif_right_accepted),
        .spdif_out(spdif_out)
    );
 

    crossdomain_flag crsdom_flg_left_accept (
        .reset(reset),
        .clk_a(clk_6p140M),
        .clk_b(clk),
        .flag_domain_a(spdif_left_accepted),
        .flag_domain_b(left_accepted)
    );


    crossdomain_flag crsdom_flg_right_accept (
        .reset(reset),
        .clk_a(clk_6p140M),
        .clk_b(clk),
        .flag_domain_a(spdif_right_accepted),
        .flag_domain_b(right_accepted)
    );
endmodule
