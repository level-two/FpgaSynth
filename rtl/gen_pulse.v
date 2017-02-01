// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: gen_pulse.v
// Description: Simple pulse generator
// -----------------------------------------------------------------------------

`include "globals.vh"

module gen_pulse (
    input             clk,
    input             reset,

    input             gen_left_sample,
    input             gen_right_sample,

    input             midi_rdy,
    input  [`MIDI_CMD_SIZE-1:0] midi_cmd,
    input  [3:0]      midi_ch_sysn,
    input  [6:0]      midi_data0,
    input  [6:0]      midi_data1,

    output reg        left_sample_rdy,
    output reg signed [17:0] left_sample_out,

    output reg        right_sample_rdy,
    output reg signed [17:0] right_sample_out
);


    reg  [31:0] divider_cnt;
    wire        divider_cnt_evnt = (divider_cnt == 0);
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            divider_cnt <= 0;
        end
        else if (divider_cnt == 32'd113_636) begin
            // 440 Hz, when CLK is 100 MHz
            divider_cnt <= 0;
        end
        else begin
            divider_cnt <= divider_cnt + 1;
        end
    end


    reg signed [17:0] sample_val;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            sample_val <= 18'h04000;
        end
        else if (divider_cnt_evnt) begin
            sample_val <= -sample_val;
        end
    end

    
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            left_sample_out  <= 0;
            left_sample_rdy  <= 0;
            right_sample_out <= 0;
            right_sample_rdy <= 0;
        end
        else if (gen_left_sample) begin
            left_sample_out  <= sample_val;
            left_sample_rdy  <= 1;
        end
        else if (gen_right_sample) begin
            right_sample_out <= sample_val;
            right_sample_rdy <= 1;
        end
        else begin
            left_sample_rdy  <= 0;
            right_sample_rdy <= 0;
        end
    end
endmodule

