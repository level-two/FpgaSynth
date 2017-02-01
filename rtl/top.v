// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: top.v
// Description: Top level module with external FPGA interface
// -----------------------------------------------------------------------------

`include "globals.vh"

module top (
    input            CLK_50M,
    input      [0:0] PB,      // UART rx
    input      [0:0] PMOD4,   // UART rx
    output     [0:0] PMOD3    // dac out
);

    wire rx = PMOD4[0];

    wire dac_left_out;
    assign PMOD3[0] = dac_left_out;

    wire clk;
    wire clk_6p140M;

    /*
    wire locked;
    wire reset_n = locked & PB[0];
    wire reset   = ~reset_n;
    */
    wire clk_valid;
    wire reset_n = clk_valid & PB[0];
    wire reset   = ~reset_n;

    ip_clk_gen_100M clk_gen
    (
        .clk_in_50M(CLK_50M), 
        .clk_out_100M(clk), 
        .CLK_VALID(clk_valid)
    );


    wire        data_received;
    wire [7:0]  data;

    wire        midi_rdy;
    wire [`MIDI_CMD_SIZE-1:0] midi_cmd;
    wire [3:0]  midi_ch_sysn;
    wire [6:0]  midi_data0;
    wire [6:0]  midi_data1;

    wire        gen_left_sample;
    wire        gen_right_sample;

    wire [17:0] left_sample;
    wire [17:0] right_sample;


    uart_rx #(.CLK_FREQ(`CLK_FREQ), .BAUD_RATE(31250)) uart_rx
    (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .data_received(data_received),
        .data(data)
    );


    midi_decoder midi_decoder (
        .clk(clk),
        .reset(reset),
        .dataInReady(data_received),
        .dataIn(data),

        .midi_rdy(midi_rdy),
        .midi_cmd(midi_cmd),
        .midi_ch_sysn(midi_ch_sysn),
        .midi_data0(midi_data0),
        .midi_data1(midi_data1)
    );


    ctrl ctrl (
        .clk(clk),
        .reset(reset),
        .gen_left_sample(gen_left_sample),
        .gen_right_sample(gen_right_sample)
    );


    gen_pulse gen_pulse (
        .clk(clk),
        .reset(reset),

        .gen_left_sample(gen_left_sample),
        .gen_right_sample(gen_right_sample),

        .midi_rdy(midi_rdy),
        .midi_cmd(midi_cmd),
        .midi_ch_sysn(midi_ch_sysn),
        .midi_data0(midi_data0),
        .midi_data1(midi_data1),

        .left_sample_out(left_sample),
        .right_sample_out(right_sample)
    );


    sigma_delta_dac #(.NBITS(2), .MBITS(16)) right_sigma_delta_dac
    (
        .clk(clk),
        .reset(reset),
        .din(right_sample),
        .dout(dac_right_out)
    );

    sigma_delta_dac #(.NBITS(2), .MBITS(16)) left_sigma_delta_dac
    (
        .clk(clk),
        .reset(reset),
        .din(left_sample),
        .dout(dac_left_out)
    );
endmodule
