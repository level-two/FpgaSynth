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

    // Inputs

    reg            CLK_50M;
    reg      [0:0] PB;
    reg      [0:0] PMOD3;   // UART rx
    wire     [0:0] PMOD4;   // SPDIF out

    top dut (
        .CLK_50M(CLK_50M),
        .PB(PB),
        .PMOD4(PMOD4),
        .PMOD3(PMOD3)
    );
    
    initial $timeformat(-9, 0, " ns", 0);

    initial begin
        CLK_50M = 0;
        PB      = 1;
    end

    always begin
        #(CLK_PERIOD/2) CLK_50M = ~CLK_50M;
    end


    wire [7:0]midi_data[0:2] = {8'h90, 8'h45, 8'h77};
    integer msg_cnt = 0;
    integer bit_cnt = 0;

	initial begin
        PMOD3 <= 1;
        #BAUD_PERIOD;
        #BAUD_PERIOD;
        #BAUD_PERIOD;
        #BAUD_PERIOD;
		
		repeat (3) begin
			PMOD3 <= 0;
			bit_cnt = 0;
            #BAUD_PERIOD;
			
			repeat (8) begin
				PMOD3 <= midi_data[msg_cnt][bit_cnt];
				bit_cnt = bit_cnt+1;
                #BAUD_PERIOD;
			end
			
			PMOD3 <= 1;
            #BAUD_PERIOD;

			msg_cnt = msg_cnt+1;
		end
    end
endmodule

