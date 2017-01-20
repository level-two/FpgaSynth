// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: tb_spdif.v
// Description: Testbench for the SPDIF module
// -----------------------------------------------------------------------------

`timescale 1ns/100ps

module tb_spdif();
    localparam TIMESTEP = 1e-9;
	localparam CLK_FREQ = 6_144_000;
	real CLK_PERIOD = (1 / (TIMESTEP * CLK_FREQ));

    reg        clk;
    reg        reset;

    reg [15:0] left_in;
    reg [15:0] right_in;
    wire       left_accepted;
    wire       right_accepted;
    wire       spdif;


    // dut
    spdif dut (
        .clk(clk),
        .reset(reset),
        .left_in(left_in),
        .right_in(right_in),
        .left_accepted(left_accepted),
        .right_accepted(right_accepted),
        .spdif(spdif)
    );

    always begin
        #(CLK_PERIOD/2);
        clk <= ~clk;
    end

    initial begin
        clk <= 0;
        reset <= 1;

        left_in <= 0;
        right_in <= 0;

        repeat (100) @(posedge clk);

        reset <= 0;
    end

    always @(posedge clk) begin
        if (right_accepted) begin
            repeat(13) @(posedge clk);
            left_in <= $random();
        end
        else if (left_accepted) begin
            repeat(13) @(posedge clk);
            right_in <= $random();
        end
    end
endmodule
