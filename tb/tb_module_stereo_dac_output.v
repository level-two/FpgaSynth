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

        repeat (100) begin : SAMPLES
            reg [15:0] val;

            sample_in_rdy   <= 1;
            //val = $random();
            val = 16'h0000;
            sample_in_l     <= {2'b0, val};
            //val = $random();
            val = 16'h8000;
            sample_in_r     <= {2'b0, val};

            @(posedge clk);
            sample_in_rdy <= 0;
            repeat (2079) @(posedge clk);
        end

        #100;

        $finish;
    end

endmodule
