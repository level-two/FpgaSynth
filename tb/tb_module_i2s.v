// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: tb_module_stereo_dac_output.v
// Description: Test bench for interpolating stereo sigma-delta DAC
// -----------------------------------------------------------------------------

`include "../rtl/globals.vh"

module tb_module_i2s();
    localparam CLK_FREQ        = 100_000_000;
    localparam SAMPLE_WIDTH    = 16;
    localparam SAMPLE_RATE     = 48000;
    localparam SAMPLE_FREQ     = SAMPLE_RATE * SAMPLE_WIDTH * 2;
    localparam SAMPLE_NCLKS    = CLK_FREQ / SAMPLE_FREQ;
    localparam SAMPLE_NCLKS_2X = SAMPLE_NCLKS / 2;

    reg                      clk;
    reg                      reset;
    reg                      bclk;
    reg                      lrclk;
    reg                      adcda;
    reg  [SAMPLE_WIDTH-1:0]  left_in;
    reg  [SAMPLE_WIDTH-1:0]  right_in;

    wire [SAMPLE_WIDTH-1:0]  left_out;
    wire [SAMPLE_WIDTH-1:0]  right_out;
    wire                     dataready;
    wire                     bclk_s;
    wire                     lrclk_s;
    wire                     dacda;

    // dut
    module_i2s #(SAMPLE_WIDTH) dut (
        .clk        (clk            ),
        .reset      (reset          ),
        .bclk       (bclk           ),
        .lrclk      (lrclk          ),
        .adcda      (adcda          ),
        .left_in    (left_in        ),
        .right_in   (right_in       ),
        .left_out   (left_out       ),
        .right_out  (right_out      ),
        .dataready  (dataready      ),
        .bclk_s     (bclk_s         ),
        .lrclk_s    (lrclk_s        ),
        .dacda      (dacda          )
    );


    initial $timeformat(-9, 0, " ns", 0);

    always begin
        #5;
        clk <= ~clk;
    end


    initial begin
        clk             <= 0;
        reset           <= 1;
        repeat (100) @(posedge clk);
        reset <= 0;
    end


    initial begin
        bclk            <= 0;
        lrclk           <= 0;
        adcda           <= 0;

        @(posedge clk);
        while (reset) @(posedge clk);

        bclk            <= 0;
        lrclk           <= 0;
        adcda           <= 0;

        forever begin
            repeat (2) begin
                repeat (SAMPLE_WIDTH) begin
                    repeat (SAMPLE_NCLKS_2X) @(posedge clk);
                    bclk  <= 1'b1;
                    repeat (SAMPLE_NCLKS_2X) @(posedge clk);
                    bclk  <= 1'b0;
                    adcda <= $random % 2;
                end
                lrclk     <= ~lrclk;
            end
        end
    end


    initial begin
        left_in         <= 0;
        right_in        <= 0;
        @(posedge clk);

        while (reset) @(posedge clk);

        repeat (SAMPLE_NCLKS) @(posedge clk);
        left_in         <= $random();
        right_in        <= $random();
    end

endmodule
