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

module tb_module_stereo_dac_output();
    reg                clk;
    reg                reset;

    reg                sample_in_rdy;
    reg  signed [17:0] sample_in_l;
    reg  signed [17:0] sample_in_r;

    wire               dac_out_l;
    wire               dac_out_r;

    // dut
    module_stereo_dac_output dut (
        .clk              (clk             ),
        .reset            (reset           ),

        .sample_in_rdy    (sample_in_rdy   ),
        .sample_in_l      (sample_in_l     ),
        .sample_in_r      (sample_in_r     ),

        .dac_out_l        (dac_out_l       ),
        .dac_out_r        (dac_out_r       )
    );


    initial $timeformat(-9, 0, " ns", 0);

    always begin
        #5;
        clk <= ~clk;
    end


    initial begin
            clk             <= 0;
            reset           <= 1;

            sample_in_rdy   <= 0;
            sample_in_l     <= 0;
            sample_in_r     <= 0;

        repeat (100) @(posedge clk);
            reset <= 0;

        repeat (100) @(posedge clk);

        sample_in_l     <= 18'h00000;
        sample_in_r     <= 18'h01000;

        repeat (100) begin : SAMPLES
            sample_in_rdy   <= 1;
            @(posedge clk);
            sample_in_rdy   <= 0;
            repeat (2079) @(posedge clk);
            sample_in_rdy   <= 1;
            @(posedge clk);
            sample_in_rdy   <= 0;
            repeat (2079) @(posedge clk);

            sample_in_r     <= ~sample_in_r;

            sample_in_rdy   <= 1;
            @(posedge clk);
            sample_in_rdy   <= 0;
            repeat (2079) @(posedge clk);
            sample_in_rdy   <= 1;
            @(posedge clk);
            sample_in_rdy   <= 0;
            repeat (2079) @(posedge clk);
        end

        #100;

        $finish;
    end
endmodule
