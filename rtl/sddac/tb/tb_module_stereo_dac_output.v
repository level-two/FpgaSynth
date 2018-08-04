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


   // 18'h20000 = -2.0
   // 18'h1FFFF <  2.0
    function [17:0] real_to_sample;
        input real real_val;
        begin
            if (real_val < -2.0 || real_val >= 2.0) begin
                $display("real_to_sample: input is out of range %f", real_val);
            end
            else begin
                real_to_sample = real_val * (1 << 16);
            end
        end
    endfunction


    function [17:0] sin_sample;
        input real freq;
        input real cur_time;
        real       cur_sin_val;
        begin
            cur_sin_val = 0.5; //$sin(2*`M_PI*freq*cur_time);
            sin_sample  = real_to_sample(cur_sin_val);
        end
    endfunction


    wire               midi_rdy;
    wire [`MIDI_CMD_SIZE-1:0] midi_cmd;
    wire [3:0]         midi_ch_sysn;
    wire [6:0]         midi_data0;
    wire [6:0]         midi_data1;
    wire               new_sample_trig;
    wire               pgen_smp_out_rdy;
    wire signed [17:0] pgen_smp_out_l;
    wire signed [17:0] pgen_smp_out_r;

    gen_sine gen_sine_inst (
        .clk                  (clk                       ),
        .reset                (reset                     ),
        .midi_rdy             (midi_rdy                  ),
        .midi_cmd             (midi_cmd                  ),
        .midi_ch_sysn         (midi_ch_sysn              ),
        .midi_data0           (midi_data0                ),
        .midi_data1           (midi_data1                ),
        .smp_rate_trig        (new_sample_trig           ),
        .smp_out_rdy          (pgen_smp_out_rdy          ),
        .smp_out_l            (pgen_smp_out_l            ),
        .smp_out_r            (pgen_smp_out_r            ),
        .dsp_outs_flat_l      (pgen_dsp_outs_flat_l      ),
        .dsp_outs_flat_r      (pgen_dsp_outs_flat_r      ),
        .dsp_ins_flat_l       (pgen_dsp_ins_flat_l       ),
        .dsp_ins_flat_r       (pgen_dsp_ins_flat_r       )
    );






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
        f = $fopen("c:\output.txt", "w");

        reset           <= 1;

        sample_in_rdy   <= 0;
        sample_in_l     <= 0;
        sample_in_r     <= 0;

        repeat (100) @(posedge clk);
            reset <= 0;

        repeat (100) begin
            sample_in_r     <= sin_sample(SIN_FREQ, $time());
            sample_in_l     <= sin_sample(SIN_FREQ, $time());
            sample_in_rdy   <= 1;
            @(posedge clk);
            sample_in_rdy   <= 0;
            repeat (SAMPLE_CLKS) @(posedge clk);
        end

        #100;

        $fclose(f);
        $finish;
    end

   
    initial begin
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
