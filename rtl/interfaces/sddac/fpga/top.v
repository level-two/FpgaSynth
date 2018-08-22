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
    input  [1:0]     BTN    ,
    input  [7:7]     GPIO_0 , // uart rx input
    input  [7:7]     GPIO_1 , // sddac output
    output [1:0]     LED
);

    wire   dac_out;

    wire clk;
    wire clk_valid;

    wire reset_n = clk_valid & BTN[0];
    wire reset   = ~reset_n;

    wire   uart_rx = GPIO_0[7];
    assign GPIO_0[7]    = dac_out;
    assign LED[0]       = 0;
    assign LED[1]       = 0;


    ip_clk_gen_100M  clk_gen
    (
        .clk_in_50M     (CLK_50M           ), 
        .clk_out_100M   (clk               ), 
        .CLK_VALID      (clk_valid         )
    );


    synth_top  synth_top (
        .clk            (clk               ),
        .reset          (reset             ),
        .uart_rx        (uart_rx           ),
        .dac_out        (dac_out           )
    );

endmodule
