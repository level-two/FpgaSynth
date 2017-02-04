// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: tb_spdif.v
// Description: Testbench for the data crossing clock domain block
// -----------------------------------------------------------------------------

`timescale 1ns/100ps

module tb_crossdomain_data();
    localparam TIMESTEP     = 1e-9;

    localparam A_CLK_FREQ   = 100_000_000;
    real       A_CLK_PERIOD = (1 / (TIMESTEP * A_CLK_FREQ));

    localparam B_CLK_FREQ   = 6_144_000;
    real       B_CLK_PERIOD = (1 / (TIMESTEP * B_CLK_FREQ));

    localparam DATA_WIDTH   = 32;

    reg        clk_a;
    reg        clk_b;
    reg        reset;


    initial begin
        clk_a <= 0;
        clk_b <= 0;
    end

    always begin
        #(A_CLK_PERIOD/2);
        clk_a <= ~clk_a;
    end

    always begin
        #(B_CLK_PERIOD/2);
        clk_b <= ~clk_b;
    end


    reg [DATA_WIDTH-1:0]  data_a;
    reg                   data_stb_a;
    wire                  done_a;
    wire [DATA_WIDTH-1:0] data_b;
    wire                  data_stb_b;


    crossdomain_data #(.DATA_WIDTH(DATA_WIDTH)) dut
    (
        .reset(reset),
        .clk_a(clk_a),
        .data_a(data_a),
        .data_stb_a(data_stb_a),
        .done_a(done_a),

        .clk_b(clk_b),
        .data_b(data_b),
        .data_stb_b(data_stb_b)
    );


    initial begin
        reset      <= 1;
        data_a     <= 0;
        data_stb_a <= 0;

        repeat (100) @(posedge clk_a);
        reset <= 0;
        repeat (100) @(posedge clk_a);

        repeat (10) begin
            data_a     <= $random();
            data_stb_a <= 1;
            @(posedge clk_a);
            data_stb_a <= 0;
            while (~done_a) @(posedge clk_a);
        end
    end
endmodule
