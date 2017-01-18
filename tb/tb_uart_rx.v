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

module tb_uart_rx;

	// Inputs
	reg clk;
	reg reset;
	reg rx;

	// Outputs
	wire data_received;
	wire [7:0] data;
	
    localparam TIMESTEP = 1e-9;
	localparam CLK_FREQ = 10_000_000;
	real CLK_PERIOD = (1 / (TIMESTEP * CLK_FREQ));

	localparam BAUD_RATE = 38400;
	real BAUD_PERIOD = (1 / (TIMESTEP * BAUD_RATE));

	uart_rx #(CLK_FREQ, BAUD_RATE) dut
    (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .data_received(data_received),
        .data(data)
    );
	

	initial begin
		// Initialize Inputs
		clk = 0;
		reset = 1;
		rx = 1;

		// Wait 100 ns for global reset to finish
		#100;
		
		reset = 0;
        
		// Add stimulus here
	end
	
	always begin
		#(CLK_PERIOD/2) clk = ~clk;
	end
	
	wire[7:0] msgArr[0:5] = {8'hFF, 8'h77, 8'h11, 8'h80, 8'h00, 8'h00 };
	integer msgCounter = 0, bitCounter = 0;
	
	initial begin
		repeat (6) begin
			#BAUD_PERIOD rx = 0;
			
			bitCounter = 0;
			
			repeat (8) begin
				#BAUD_PERIOD rx = msgArr[msgCounter][bitCounter];
				bitCounter = bitCounter+1;
			end
			
			#BAUD_PERIOD rx = 1;
			msgCounter = msgCounter+1;
			
			#100;
		end
	end
endmodule

