// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: top_xil_spartan6.v
// Description: Top level module with external Logi-Pi board interface
// -----------------------------------------------------------------------------

`include "globals.vh"

module top (
    input            CLK_50M,
    input      [0:0] PB,
    input      [0:0] PMOD3,
    output           PMOD4_4,
    input            PMOD4_5,
    input            PMOD4_6,
    input            PMOD4_7,
    output     [1:0] LED
);

    wire i2s_lrclk_in;
    wire i2s_bclk_in;
    wire i2s_data_in;
    wire i2s_data_out;

    wire   uart_rx      = PMOD3[0];
    assign PMOD4_4     = i2s_data_out;
    assign i2s_data_in  = PMOD4_5;
    assign i2s_bclk_in  = PMOD4_6;
    assign i2s_lrclk_in = PMOD4_7;
    assign LED[0]       = 0;
    assign LED[1]       = 0;

    wire clk;
    wire clk_valid;
    wire reset_n = clk_valid & PB[0];
    wire reset   = ~reset_n;

    ip_clk_gen_100M  clk_gen
    (
        .clk_in_50M  (CLK_50M  ), 
        .clk_out_100M(clk      ), 
        .CLK_VALID   (clk_valid)
    );

    synth_top  synth_top (
        .clk            (clk            ),
        .reset          (reset          ),
        .uart_rx        (uart_rx        ),
        .i2s_lrclk_in   (i2s_lrclk_in   ),
        .i2s_bclk_in    (i2s_bclk_in    ),
        .i2s_data_in    (i2s_data_in    ),
        .i2s_data_out   (i2s_data_out   )
    );

endmodule
