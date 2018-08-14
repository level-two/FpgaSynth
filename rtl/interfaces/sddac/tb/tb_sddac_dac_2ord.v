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
    reg signed [17:0] sample_in_l;
    reg signed [17:0] sample_in_r;
    reg               sample_in_rdy;
    wire              dout_l;
    wire              dout_r;

    sigma_delta_2order_dac  dut
    (
        .clk              (clk                  ),
        .reset            (reset                ),
        .sample_in_l      (sample_in_l          ),
        .sample_in_r      (sample_in_r          ),
        .sample_in_rdy    (sample_in_rdy        ),
        .dout_l           (dout_l               ),
        .dout_r           (dout_r               )
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
        sample_in_l      <= 18'h00000;
        sample_in_r      <= 18'h00000;
        sample_in_rdy    <= 1'b0;

        repeat (100) @(posedge clk);

        reset       <= 1'b0;
        sample_in_l <= 18'h00000;
        sample_in_r <= 18'h04000;

        @(posedge clk);

        repeat (500) begin
            sample_in_r      <= sample_in_r + 18'h00004;
            sample_in_rdy    <= 1'b1;
            @(posedge clk);
            sample_in_rdy    <= 1'b0;
            repeat (100) @(posedge clk);
        end
        
        $finish;
    end


    always @(posedge clk) begin
        if (sample_in_rdy) begin
            $display("%d", dout_r);
        end
    end

endmodule

