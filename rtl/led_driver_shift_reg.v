// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: led_driver_shift_reg.v
// Description: Shift register for WS2812B LED driver
// -----------------------------------------------------------------------------

module led_driver_shift_reg #(parameter DATA_WIDTH = 32, parameter SHIFT_WIDTH = 32)
(
    input  clk,
    input  reset,

    input  [DATA_WIDTH-1:0] data_in,
    input  load,
    input  next_bit,
    output bit_val,
    output last_bit
);

    `include "globals.vh"

    localparam SHIFT_WIDTH_NBITS = clogb2(SHIFT_WIDTH) + 1;

    reg [SHIFT_WIDTH_NBITS-1:0] cnt;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            cnt <= 0;
        end
        else begin
            if (load) begin
                cnt <= SHIFT_WIDTH-1;
            end
            else if (next_bit) begin
                cnt <= cnt - 1;
            end
        end
    end 

    assign last_bit = (cnt == 0);

    reg [DATA_WIDTH-1:0] data;
    assign bit_val = data[cnt];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            data <= 0;
        end
        else begin
            if (load) begin
                data <= data_in;
            end
        end
    end 

endmodule
