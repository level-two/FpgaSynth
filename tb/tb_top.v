// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: tb_top.v
// Description: Testbench for the top module
// -----------------------------------------------------------------------------


`timescale 1ns/100ps

`include "../rtl/globals.vh"


module tb_top;
    localparam TIMESTEP = 1e-9;
    localparam CLK_FREQ = 50_000_000;
    real CLK_PERIOD = (1 / (TIMESTEP * CLK_FREQ));

    localparam BAUD_RATE = 38400;
    real BAUD_PERIOD = (1 / (TIMESTEP * BAUD_RATE));

    // Inputs

    reg            CLK_50M;
    reg      [0:0] PB;      // UART rx
    reg      [0:0] PMOD4;   // UART rx
    wire     [0:0] PMOD3;   // SPDIF out

    top dut (
        .CLK_50M(CLK_50M),
        .PB(PB),
        .PMOD4(PMOD4),
        .PMOD3(PMOD3)
    );
    
    initial $timeformat(-9, 0, " ns", 0);

    initial begin
        CLK_50M     = 0;
        PB = 1;
        PMOD4 = 0;
    end

    always begin
        #(CLK_PERIOD/2) CLK_50M = ~CLK_50M;
    end
endmodule

