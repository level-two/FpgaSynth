// -----------------------------------------------------------------------------
// Copyright � 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: spdif.v
// Description: Audio sample -> S/PDIF conversion module
// -----------------------------------------------------------------------------

module spdif (
    input         clk,
    input         reset,

    input  [15:0] left_in,
    input  [15:0] right_in,
    output reg    left_accepted,
    output reg    right_accepted,
    output reg    spdif_out
);
 

    reg [14:0] bit_cnt;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            bit_cnt <= 0;
        end
        else begin
            if (bit_cnt == 15'h5FFF)
                bit_cnt <= 0;
            else
                bit_cnt <= bit_cnt + 1'b1;
        end
    end


    // Channel: 0 - left, 1 - right
    wire        chanel   =  bit_cnt[6];
    wire [15:0] sample   = (chanel == 0) ? left_in : right_in;
    wire [7:0]  preamble = (bit_cnt[14:6] == 9'b0) ? 8'b10011100 : // B (left)
                           (chanel == 0)           ? 8'b10010011 : // M (left)
                                                     8'b10010110 ; // W (right)
    wire        sf_trig  = (bit_cnt[5:0] == 6'b0);
    wire        parity   = ^sample;

    reg  [63:0] subFrame;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            left_accepted  <= 0;
            right_accepted <= 0;
            subFrame <= 0;
        end
        else if (sf_trig) begin
            left_accepted  <= ~chanel;
            right_accepted <=  chanel;

            subFrame <= { preamble,
                         16'b1010101010101010,
                         1'b1, sample[0] , 1'b1, sample[1] , 1'b1, sample[2] , 1'b1, sample[3] ,
                         1'b1, sample[4] , 1'b1, sample[5] , 1'b1, sample[6] , 1'b1, sample[7] ,
                         1'b1, sample[8] , 1'b1, sample[9] , 1'b1, sample[10], 1'b1, sample[11],
                         1'b1, sample[12], 1'b1, sample[13], 1'b1, sample[14], 1'b1, sample[15],
                         //      V                 U                 C                 P
                         1'b1, 1'b0      , 1'b1, 1'b0      , 1'b1, 1'b0      , 1'b1, parity
                        };
        end
        else begin
            left_accepted  <= 0;
            right_accepted <= 0;
            subFrame <= subFrame << 1'b1; // left shift to output
        end
    end

    // BMC coder
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            spdif_out <= 0;
        end
        else begin
            spdif_out <= spdif_out ^ subFrame[63];
        end
    end

endmodule
