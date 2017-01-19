// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: spdif.v
// Description: Audio sample -> S/PDIF conversion module
// -----------------------------------------------------------------------------

module spdif_out (
    input         clk_6144k,
    input         reset,

    input  [15:0] left_in,
    input  [15:0] right_in,
    output        next_sample_req,
    output reg    spdif
);
 

// overflowing bit counter 0-63
reg [5:0] sf_bit_cnt;

always @(posedge reset or posedge clk_6144k) begin
    if (reset) begin
        sf_bit_cnt <= 0;
    end
    else begin
        sf_bit_cnt <= sf_bit_cnt + 1'b1;
    end
end

wire        subFrame_trig = (sf_bit_cnt == 6'b0);
reg [8:0]   subFrame_cnt;

always @(posedge reset or posedge clk_6144k) begin
    if (reset) begin
        subFrame_cnt <= 0;
    end
    else if (subFrame_trig) begin
        if (subFrame_cnt == 9'd383) // 192*2-1
            subFrame_cnt <= 0;
        else 
            subFrame_cnt <= subFrame_cnt + 1'b1;
    end
end


reg         parity;
reg  [63:0] subFrame;
wire [15:0] sample        = subFrame_cnt[0] ? left_in : right_in;
 
// sub-frame header (B - M - W Preamble)
wire [7:0]  preamble = (subFrame_cnt    == 9'd383) ? 8'b10011100 :
                       (subFrame_cnt[0] == 1)      ? 8'b10010011 :
                                                     8'b10010110 ;
 
// new sub-frame creation
always @(posedge reset or posedge clk_6144k) begin
    if (reset) begin
        parity   <= 0;
        subFrame <= 0;
    end
    else if (subFrame_trig) begin
        parity   <= ^sample;
        subFrame <= { preamble,
                     16'b1010101010101010,
                     //      V                 U                 C                 P
                     1'b1, sample[0] , 1'b1, sample[1] , 1'b1, sample[2] , 1'b1, sample[3] ,
                     1'b1, sample[4] , 1'b1, sample[5] , 1'b1, sample[6] , 1'b1, sample[7] ,
                     1'b1, sample[8] , 1'b1, sample[9] , 1'b1, sample[10], 1'b1, sample[11],
                     1'b1, sample[12], 1'b1, sample[13], 1'b1, sample[14], 1'b1, sample[15],
                     1'b1, 1'b0      , 1'b1, 1'b0      , 1'b1, 1'b0      , 1'b1, parity
                    };
    end
    else begin
        subFrame <= subFrame << 1'b1; // left shift to output
    end
end
                         
// BMC coder
always @(posedge reset or posedge clk_6144k) begin
    if (reset) begin
        spdif <= 0;
    end
    else begin
        spdif <= spdif ^ subFrame[63];
    end
end
                         
endmodule
