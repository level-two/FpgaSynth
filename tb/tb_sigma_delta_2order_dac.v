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
    real CLK_PERIOD     = (1 / (TIMESTEP * CLK_FREQ));

    // Inputs
    reg               clk;
    reg               reset;
    reg signed [17:0] sample_in;
    reg               sample_in_rdy;
    reg               sample_rate_trig;
    wire              dout;

    sigma_delta_2order_dac  dut
    (
        .clk              (clk                  ),
        .reset            (reset                ),
        .sample_in        (sample_in            ),
        .sample_in_rdy    (sample_in_rdy        ),
        .sample_rate_trig (sample_rate_trig     ),
        .dout             (dout                 )
    );

    
    initial $timeformat(-9, 0, " ns", 0);

    initial begin
        clk <= 0;
    end

    always begin
        #(CLK_PERIOD/2) clk = ~clk;
    end

    initial begin
        reset            <= 1'b1;
        sample_in        <= 18'h00000;
        sample_in_rdy    <= 1'b0;
        sample_rate_trig <= 1'b0;

        #100;
        reset     <= 1'b0;
        sample_in <= 18'h30000; // Q2.16

        repeat ('h20) begin
            repeat (1000000) @(posedge clk);
            sample_in        <= -sample_in;// + 18'h00100; // Q2.16
            sample_in_rdy    <= 1'b1;

            @(posedge clk);
            sample_in_rdy    <= 1'b0;
            sample_rate_trig <= 1'b1;

            @(posedge clk);
            sample_rate_trig <= 1'b0;
        end
        
        repeat (10000) @(posedge clk);
        $finish;
    end
endmodule

