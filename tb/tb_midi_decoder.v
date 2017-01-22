// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: tb_uart_rx.v
// Description: Testbench for the UART receiver controller
// -----------------------------------------------------------------------------


`timescale 1ns/100ps

`include "../rtl/globals.vh"


module tb_midi_decoder;
    localparam TIMESTEP = 1e-9;
    localparam CLK_FREQ = 150_000_000;
    real CLK_PERIOD = (1 / (TIMESTEP * CLK_FREQ));

    localparam BAUD_RATE = 38400;
    real BAUD_PERIOD = (1 / (TIMESTEP * BAUD_RATE));

    // Inputs
    reg clk;
    reg reset;

    reg        dataInReady;
    reg  [7:0] dataIn;

    // Parsed MIDI message
    wire       midi_rdy;
    wire [`MIDI_CMD_SIZE:0] midi_cmd;
    wire [3:0] midi_ch_sysn;
    wire [6:0] midi_data0;
    wire [6:0] midi_data1;

    midi_decoder dut (
        .clk(clk),
        .reset(reset),
        .dataInReady(dataInReady),
        .dataIn(dataIn),
        .midi_rdy(midi_rdy),
        .midi_cmd(midi_cmd),
        .midi_ch_sysn(midi_ch_sysn),
        .midi_data0(midi_data0),
        .midi_data1(midi_data1)
    );
    
    initial $timeformat(-9, 0, " ns", 0);

    integer msgCounter = 0;

    initial begin
        // Initialize Inputs
        clk         = 0;
        reset       = 1;

        dataInReady = 0;
        dataIn      = 0;

        #100;

        reset = 0;

        #100;

        $display("[%t] [%m]: Testing correct data", $time);

        repeat (100) begin
            @(posedge clk);
            dataInReady = 1;
            dataIn      = $random() % 'h100;
            dataIn[7]   = 1;

            @(posedge clk);
            dataInReady = 0;

            #BAUD_PERIOD;


            repeat (2) begin
                @(posedge clk);
                dataInReady = 1;
                dataIn      = $random() % 'h100;
                dataIn[7]   = 0;

                @(posedge clk);
                dataInReady = 0;
                #BAUD_PERIOD;
            end
        end
    end


    always begin
        #(CLK_PERIOD/2) clk = ~clk;
    end
endmodule

