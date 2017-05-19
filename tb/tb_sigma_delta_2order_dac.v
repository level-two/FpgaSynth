// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: tb_sigma_delta_dac.v
// Description: Testbench for the sigma-delta adc
// -----------------------------------------------------------------------------


`timescale 1ns/100ps

`include "../rtl/globals.vh"


module tb_sigma_delta_2order_dac;
    localparam TIMESTEP = 1e-9;
    localparam CLK_FREQ = 100_000_000;
    real CLK_PERIOD = (1 / (TIMESTEP * CLK_FREQ));

    // Inputs
    reg             clk;
    reg             reset;   // SPDIF out

    reg signed [17:0] din;
    wire              dout;

    sigma_delta_2order_dac #(.NBITS(2), .MBITS(16)) dut
    (
        .clk(clk),
        .reset(reset),
        .din(din),
        .dout(dout)
    );

    
    initial $timeformat(-9, 0, " ns", 0);

    initial begin
        clk <= 0;
    end

    always begin
        #(CLK_PERIOD/2) clk = ~clk;
    end

    initial begin
        reset <= 1;
        din   <= 0;
        #100;
        reset <= 0;

        din <= 18'h30000; // Q2.16
        repeat (8) begin
            repeat (10000) @(posedge clk);
            din <= din + 18'h04000; // Q2.16
        end
        
        repeat (10000) @(posedge clk);
        $finish;
    end
endmodule

