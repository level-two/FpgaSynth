// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: tb_module_lpf.v
// Description: Test bench for the LPF module
// -----------------------------------------------------------------------------

`include "../rtl/globals.vh"

module tb_module_lpf();
    reg                reset;
    reg                clk;

    reg                midi_rdy;
    reg  [`MIDI_CMD_SIZE-1:0] midi_cmd;
    reg  [3:0]         midi_ch_sysn;
    reg  [6:0]         midi_data0;
    reg  [6:0]         midi_data1;

    reg                sample_in_rdy;
    reg signed [17:0]  sample_in;

    wire               sample_out_rdy;
    wire signed [17:0] sample_out;


    // dut
    module_lpf dut (
        .clk            (clk            ),
        .reset          (reset          ),

        .midi_rdy       (midi_rdy       ),
        .midi_cmd       (midi_cmd       ),
        .midi_ch_sysn   (midi_ch_sysn   ),
        .midi_data0     (midi_data0     ),
        .midi_data1     (midi_data1     ),

        .sample_in_rdy  (sample_in_rdy  ),
        .sample_in      (sample_in      ),

        .sample_out_rdy (sample_out_rdy ),
        .sample_out     (sample_out     )
    );


    always begin
        #0.5;
        clk <= ~clk;
    end


    initial begin
            clk           <= 0;
            reset         <= 1;

            midi_rdy      <= 0;
            midi_cmd      <= 0;
            midi_ch_sysn  <= 0;
            midi_data0    <= 0;
            midi_data1    <= 0;
            sample_in_rdy <= 0;
            sample_in     <= 0;

        repeat (100) @(posedge clk);
            reset <= 0;

        repeat (100) @(posedge clk);

        repeat (10) begin
            sample_in_rdy <= 1;
            sample_in     <= $random();
            @(posedge clk);
            sample_in_rdy <= 0;
            repeat (1000) @(posedge clk);
        end

        #100;
    end

endmodule
