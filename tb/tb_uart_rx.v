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
	localparam CLK_FREQ = 150_000_000;
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
	
    initial $timeformat(-9, 0, " ns", 0);

    reg[7:0] rnd_data;
	integer msgCounter = 0, bitCounter = 0;

    reg data_received_trig;
    always @(data_received) begin
        data_received_trig <= 1;
    end


	initial begin
		// Initialize Inputs
		clk = 0;
		reset = 1;
		rx = 1;
		#100;
		reset = 0;
		#100;

        $display("[%t] [%m]: Testing correct data", $time);

		repeat (10) begin
            rnd_data = $random() % 'h100;
            data_received_trig <= 0;

			rx = 0;
			bitCounter = 0;
            #BAUD_PERIOD;
			
			repeat (8) begin
				rx = rnd_data[bitCounter];
				bitCounter = bitCounter+1;
                #BAUD_PERIOD;
			end
			
			rx = 1;
            #BAUD_PERIOD;

            if (data_received_trig == 0) $display("[%t] [%m]: ERROR: data_received is 0 while expected 1!", $time);
            if (rnd_data != data)        $display("[%t] [%m]: ERROR: data %h is not equal to expected %h!", $time, data, rnd_data);

			msgCounter = msgCounter+1;
		end

        //-------------------------------------------

        $display("[%t] [%m]: Testing incorrect final bit (0)", $time);

		repeat (10) begin
            rnd_data = $random() % 'h100;
            data_received_trig <= 0;

			rx = 0;
			bitCounter = 0;
            #BAUD_PERIOD;
			
			repeat (8) begin
				rx = rnd_data[bitCounter];
				bitCounter = bitCounter+1;
                #BAUD_PERIOD;
			end
			
			rx = 0;

            #BAUD_PERIOD;

            if (data_received_trig == 1) $display("[%t] [%m]: ERROR: data_received is 1 while expected 0!", $time);

			msgCounter = msgCounter+1;

            // return lane to initial state
			rx = 1;
            #BAUD_PERIOD;
		end
	end
	
	always begin
		#(CLK_PERIOD/2) clk = ~clk;
	end
endmodule

