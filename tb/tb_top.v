// -----------------------------------------------------------------------------
// Copyright � 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: tb_top.v
// Description: Testbench for the top module
// -----------------------------------------------------------------------------


`timescale 1ns/100ps

`include "../rtl/globals.vh"


module tb_top;
    localparam TIMESTEP = 1e-9;
    localparam CLK_FREQ = 50_000_000;
    real CLK_PERIOD = (1 / (TIMESTEP * CLK_FREQ));

    localparam BAUD_RATE = 38400;
    real BAUD_PERIOD = (1 / (TIMESTEP * BAUD_RATE));

    localparam SAMPLE_WIDTH    = 16;
    localparam SAMPLE_RATE     = 48000;
    localparam SAMPLE_FREQ     = SAMPLE_RATE * SAMPLE_WIDTH * 2;
    localparam SAMPLE_NCLKS    = CLK_FREQ / SAMPLE_FREQ;
    localparam SAMPLE_NCLKS_HALF = SAMPLE_NCLKS / 2;


    reg        CLK_50M;
    reg [0:0]  PB;
    reg        SYS_TX;   // UART rx
    wire       PMOD4_4;
    reg        PMOD4_5;
    reg        PMOD4_6;
    reg        PMOD4_7;
    wire [1:0] LED;     // LED out

    top dut (
        .CLK_50M(CLK_50M),
        .PB(PB),
        .PMOD4_4(PMOD4_4),
        .PMOD4_5(PMOD4_5),
        .PMOD4_6(PMOD4_6),
        .PMOD4_7(PMOD4_7),
        .SYS_TX(SYS_TX),
        .LED(LED)
    );
    
    initial $timeformat(-9, 0, " ns", 0);

    initial begin
        CLK_50M = 0;
        PB      = 1;
    end

    always begin
        #(CLK_PERIOD/2) CLK_50M = ~CLK_50M;
    end


    wire [7:0]midi_data[0:5] = {8'h90, 8'h56, 8'h20, 8'h80, 8'h56, 8'h20};
    integer msg_cnt = 0;
    integer bit_cnt = 0;

	initial begin
        SYS_TX <= 1;
        /*
        #BAUD_PERIOD;
        #BAUD_PERIOD;
        #BAUD_PERIOD;
        #BAUD_PERIOD;
		
		repeat (3) begin
			SYS_TX <= 0;
			bit_cnt = 0;
            #BAUD_PERIOD;
			
			repeat (8) begin
				SYS_TX <= midi_data[msg_cnt][bit_cnt];
				bit_cnt = bit_cnt+1;
                #BAUD_PERIOD;
			end
			
			SYS_TX <= 1;
            #BAUD_PERIOD;

			msg_cnt = msg_cnt+1;
		end

        #3000000;

		
		repeat (3) begin
			SYS_TX <= 0;
			bit_cnt = 0;
            #BAUD_PERIOD;
			
			repeat (8) begin
				SYS_TX <= midi_data[msg_cnt][bit_cnt];
				bit_cnt = bit_cnt+1;
                #BAUD_PERIOD;
			end
			
			SYS_TX <= 1;
            #BAUD_PERIOD;

			msg_cnt = msg_cnt+1;
		end
        */
    end


    initial begin
        PMOD4_7 <= 0;
        PMOD4_6 <= 0;
        PMOD4_5 <= 0;

        @(posedge CLK_50M);

        forever begin
            repeat (2) begin
                repeat (SAMPLE_WIDTH+16) begin
                    repeat (SAMPLE_NCLKS_HALF) @(posedge CLK_50M);
                    PMOD4_6  <= 1'b1;
                    repeat (SAMPLE_NCLKS_HALF) @(posedge CLK_50M);
                    PMOD4_6  <= 1'b0;
                end
                PMOD4_7 <= ~PMOD4_7;
            end
        end
    end

endmodule

