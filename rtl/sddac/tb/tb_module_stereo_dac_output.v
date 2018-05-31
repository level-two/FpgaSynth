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

    localparam TIMESTEP      = 1e-9;
    localparam CLK_FREQ      = 100_000_000;
    localparam DAC_OUT_CLKS  = 8;
    localparam SAMPLE_CLKS   = 2082;
    real       SAMPLE_PERIOD = 1/48000;
    real       CLK_PERIOD    = (1 / (TIMESTEP * CLK_FREQ));
    real       SIN_FREQ      = 1e3;


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

    initial begin
        clk <= 0;
    end

    always begin
        #(CLK_PERIOD/2) clk = ~clk;
    end


    integer f;
    initial begin
        f = $fopen("output.txt", "w");
    end


    initial begin
        reset           <= 1;

        sample_in_rdy   <= 0;
        sample_in_l     <= 0;
        sample_in_r     <= 0;

        repeat (100) @(posedge clk);
            reset <= 0;

        repeat (100) @(posedge clk);

        sample_in_l     <= 18'h00000;
        sample_in_r     <= 18'h01000;

        repeat (100) begin
            sample_in_rdy   <= 1;
            @(posedge clk);
            sample_in_rdy   <= 0;
            repeat (SAMPLE_CLKS) @(posedge clk);




            begin : IN_CALC
                real cur_sin_val;
                cur_sin_val = $sin(2*PI*SAMPLE_FREQ*cur_time)
           
           
            sample_in_l - 18'h0001;




            sample_in_r     <= sample_in_r + 18'h0001;
        end

        #100;

        $fclose(f);
        $finish;
    end

   
    always begin
        @(posedge reset);
        @(negedge reset);
        forever begin
            repeat (DAC_OUT_CLKS) @(posedge clk);
            $fwrite(f, "%b\n",  dac_out_l); 
        end
    end


    // i = (Vin-Vout)/R
    // Vout = q/C
    // dVout/dt = i/C = (Vin-Vout)/RC
    // f = 1/2piRC
    // for f=20000 => R=1k, C=5.3nF

    /*
    real vout_l;
    real vout_r;
    localparam real R = 1e3;
    localparam real C = 5.3e-9;

    always @(posedge clk and posedge reset) begin
        if (reset) begin
            vout_l <= 0;
            vout_r <= 0;
        end
        else begin
            vout_l = vout_l + ((dac_out_l ? 3.3 : 0) - vout_l)/(R*C);
            vout_r = vout_r + ((dac_out_r ? 3.3 : 0) - vout_r)/(R*C);
        end
    end
    */
endmodule
