// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: module_lpf.v
// Description: LPF implementation based on IIR scheme and Xilinx DSP48A1
// -----------------------------------------------------------------------------

`include "globals.vh"

module module_lpf (
    input                       clk,
    input                       reset,

    input                       midi_rdy,
    input  [`MIDI_CMD_SIZE-1:0] midi_cmd,
    input  [3:0]                midi_ch_sysn,
    input  [6:0]                midi_data0,
    input  [6:0]                midi_data1,

    input                       sample_in_rdy,
    input  signed [17:0]        sample_in,

    output                      sample_out_rdy,
    output signed [17:0]        sample_out
);

    reg signed [17:0] coefs[0:4];
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            coefs[0] <= 18'h10000; // should always be 1.0
            coefs[1] <= 18'h3f000;
            coefs[2] <= 18'h01000;
            coefs[3] <= 18'h3f000;
            coefs[4] <= 18'h01000;
        end
    end


    wire [18*5-1:0] coefs_flat;
    genvar i;
    generate
        for (i = 0; i < 5; i=i+1) begin : COEFS_BLK
            assign coefs_flat[18*i +: 18] = coefs[i];
        end
    endgenerate


    alu_filter alu_filter(
        .clk            (clk            ),
        .reset          (reset          ),
        .sample_in_rdy  (sample_in_rdy  ),
        .sample_in      (sample_in      ),
        .coefs_flat     (coefs_flat     ),
        .sample_out_rdy (sample_out_rdy ),
        .sample_out     (sample_out     )
    );


//-----------------------------------------------------------------
// -------====== MIDI Events processing ======-------
//-------------------------------------------------------------
    wire      cc_event = (midi_rdy && midi_cmd == `MIDI_CMD_CC);
    reg [7:0] cc_num;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            cc_num <= 0;
        end
        else if (cc_event) begin
            cc_num <= midi_data0;
        end
    end
endmodule
