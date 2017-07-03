// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: tb_module_stereo_dac_output_sine.v
// Description: Test bench for interpolating stereo sigma-delta DAC
// -----------------------------------------------------------------------------

`include "../rtl/globals.vh"

module tb_module_stereo_dac_output_sine();
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


    localparam real PI = 3.14159265;

    function real sin;
        input x;
        real  x;
        real  x1,y,y2,y3,y5,y7,sum,sign;
    begin
        sign = 1.0;
        x1   = x;
        if (x1<0) begin
            x1   = -x1;
            sign = -1.0;
        end
        while (x1 > PI/2.0) begin
            x1   = x1 - PI;
            sign = -1.0*sign;
        end
        y   = x1*2/PI;
        y2  = y*y;
        y3  = y*y2;
        y5  = y3*y2;
        y7  = y5*y2;
        sum = 1.570794*y - 0.645962*y3 + 0.079692*y5 - 0.004681712*y7;
        sin = sign*sum;
    end
    endfunction // sin  


    localparam signed [17:0] AMPL = 18'h0ffff;
    localparam real          FREQ = 1000; // Hz

    real time_us;
    real time_s;
    real sin_val;

    initial begin
        clk           <= 0;
        reset         <= 1;
        sample_in_rdy <= 0;
        sample_in_l   <= 18'h00000;
        sample_in_r   <= 18'h00000;

        repeat (10) @(posedge clk);
        reset <= 0;

        repeat (1000) begin : SAMPLES
            time_us        = $time/1000;
            time_s         = time_us/1000000;
            sin_val        = AMPL*sin(2*PI*FREQ*time_s);
            sample_in_l   <= sin_val;
            sample_in_rdy <= 1;
            @(posedge clk);
            sample_in_rdy   <= 0;
            repeat (2079) @(posedge clk);
        end
        #100;
        $finish;
    end
endmodule
