// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: sigma_delta_dac_wrap.v
// Description: Wrapper for the sigma-delta dac. It's main task is to store
// incoming sample and pass it to the DAC with proper rate
// -----------------------------------------------------------------------------

module sigma_delta_dac_wrap
(
    input               clk,
    input               reset,
    input               smpl_rdy,
    input signed [17:0] smpl,
    input               smpl_rate_trig,
    output              dout
);

    reg signed [17:0] dac_smpl;
    reg signed [17:0] next_smpl;

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            next_smpl <= 18'h00000;
            dac_smpl  <= 18'h00000;
        end
        else begin
            if (smpl_rdy) begin
                // prevent overflow
                next_smpl <= smpl[17:16] == 2'b01 ? 18'h10000 :
                             smpl[17:16] == 2'b10 ? 18'h30000 : 
                             smpl;
            end

            if (smpl_rate_trig) begin
                dac_smpl  <= next_smpl;
            end
        end
    end

    sigma_delta_2order_dac right_sigma_delta_dac
    (
        .clk  (clk      ),
        .reset(reset    ),
        .din  (dac_smpl ),
        .dout (dout     )
    );

endmodule
