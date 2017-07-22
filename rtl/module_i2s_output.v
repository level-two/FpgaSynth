// -----------------------------------------------------------------------------
// Copyright © 2016 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: module_i2s_output.v
// Description: Wrapper module for the I2S output audio interface
//              It converts 18-bit signed sample to 17-bit signed and
//              truncates it if it's out of [-1,+1]
// -----------------------------------------------------------------------------

module module_i2s_output
(
    input               clk,
    input               reset,
    input               sample_in_rdy,
    input signed [16:0] sample_in_l,
    input signed [16:0] sample_in_r,
    output              data_sampled,
    input               bclk,       // I2S signals
    input               lrclk,
    output              dacda
);

    // Store in samples
    reg signed [16:0] sample_in_l_reg;
    reg signed [16:0] sample_in_r_reg;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            sample_in_l_reg <= 17'h00000;
            sample_in_r_reg <= 17'h00000;
        end
        else if (sample_in_rdy) begin
            sample_in_l_reg <= 
               sample_in_l[17:16] == 2'b01 ? 17'h0ffff :
               sample_in_l[17:16] == 2'b10 ? 17'h10000 : 
               {sample_in_l[17], sample_in_l[15:0]};
            sample_in_r_reg <= 
               sample_in_r[17:16] == 2'b01 ? 17'h0ffff :
               sample_in_r[17:16] == 2'b10 ? 17'h10000 : 
               {sample_in_r[17], sample_in_r[15:0]};
        end
    end


    wire adcda_nc;
    wire [16:0] left_out_nc;
    wire [16:0] right_out_nc;
    wire dataready_nc;
    wire bclk_s_nc;
    wire lrclk_s_nc;

    i2s #(.SAMPLE_WIDTH(17))
    (
        .clk            (clk            ),
        .reset          (reset          ),
        .bclk           (bclk           ),
        .lrclk          (lrclk          ),
        .adcda          (adcda_nc       ),
        .left_out       (left_out_nc    ),
        .right_out      (right_out_nc   ),
        .dataready      (dataready_nc   ),
        .left_in        (sample_in_l_reg),
        .right_in       (sample_in_r_reg),
        .data_sampled   (data_sampled   ),
        .bclk_s         (bclk_s_nc      ),
        .lrclk_s        (lrclk_s_nc     ),
        .dacda          (dacda          )
    );

endmodule
