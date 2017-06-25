// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: tb_fir_decim_384k_48k.v
// Description: Test bench for the decimating 384k->48k filter
// -----------------------------------------------------------------------------

`include "../rtl/globals.vh"

module tb_gen_pulse();
    reg                       clk;
    reg                       reset;
    wire                      sample_out_rdy;
    wire signed [17:0]        sample_out_l;
    wire signed [17:0]        sample_out_r;
    wire [47:0]               dsp_outs_flat_l;
    wire [47:0]               dsp_outs_flat_r;
    wire [91:0]               dsp_ins_flat_l;
    wire [91:0]               dsp_ins_flat_r;

    reg                       midi_rdy;
    reg  [`MIDI_CMD_SIZE-1:0] midi_cmd;
    reg  [3:0]                midi_ch_sysn;
    reg  [6:0]                midi_data0;
    reg  [6:0]                midi_data1;
    reg                       sample_rate_trig;

    gen_pulse dut(
        .clk                (clk                    ),
        .reset              (reset                  ),
        .midi_rdy           (midi_rdy               ),
        .midi_cmd           (midi_cmd               ),
        .midi_ch_sysn       (midi_ch_sysn           ),
        .midi_data0         (midi_data0             ),
        .midi_data1         (midi_data1             ),
        .sample_rate_trig   (sample_rate_trig       ),
        .sample_out_rdy     (sample_out_rdy         ),
        .sample_out_l       (sample_out_l           ),
        .sample_out_r       (sample_out_r           ),
        .dsp_outs_flat_l    (dsp_outs_flat_l        ),
        .dsp_outs_flat_r    (dsp_outs_flat_r        ),
        .dsp_ins_flat_l     (dsp_ins_flat_l         ),
        .dsp_ins_flat_r     (dsp_ins_flat_r         )
    );

    // DSP instances
    dsp48a1_inst dsp48a1_inst_l (
        .clk            (clk            ),
        .reset          (reset          ),
        .dsp_ins_flat   (dsp_ins_flat_l ),
        .dsp_outs_flat  (dsp_outs_flat_l)
    );

    dsp48a1_inst dsp48a1_inst_r (
        .clk            (clk            ),
        .reset          (reset          ),
        .dsp_ins_flat   (dsp_ins_flat_r ),
        .dsp_outs_flat  (dsp_outs_flat_r)
    );


    initial $timeformat(-9, 0, " ns", 0);

    always begin
        #0.5;
        clk <= ~clk;
    end

    always begin
        repeat (`CLK_DIV_48K-1) @(posedge clk);
        sample_rate_trig <= 1'b1;
        @(posedge clk);
        sample_rate_trig <= 1'b0;
    end


    initial begin
        clk             <= 0;
        reset           <= 1;

        sample_rate_trig <= 0;
        midi_rdy        <= 0;
        midi_cmd        <= `MIDI_CMD_NONE;
        midi_ch_sysn    <= 0;
        midi_data0      <= 0;
        midi_data1      <= 0;

        repeat (100) @(posedge clk);
        reset <= 0;
        repeat (100) @(posedge clk);

        midi_rdy        <= 1;
        midi_cmd        <= `MIDI_CMD_NOTE_ON;
        midi_ch_sysn    <= 0;
        midi_data0      <= 50;
        midi_data1      <= 48;
        @(posedge clk);
        midi_rdy        <= 0;

        repeat (1000) @(posedge sample_out_rdy);


        midi_rdy        <= 1;
        midi_cmd        <= `MIDI_CMD_NOTE_OFF;
        midi_ch_sysn    <= 0;
        midi_data0      <= 50;
        midi_data1      <= 48;
        @(posedge clk);
        midi_rdy        <= 0;


        $finish;
    end


    always @(posedge clk) begin
        if (sample_out_rdy) begin
            $display("%d", sample_out_l);
        end
    end

endmodule
