// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: task_idx_reg.v
// Description: Task for the register
// -----------------------------------------------------------------------------


module task_idx_reg (
    input                    clk,
    input                    reset,
    input                    stb_load,
    input                    stb_inc,
    input      [REG_W-1:0]   reg_in,
    output reg [REG_W-1:0]   reg_out
);

    parameter REG_W = 18;

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            reg_out <= 0;
        end
        else if (stb_load) begin
            reg_out <= reg_in;
        end
        else if (stb_inc) begin
            reg_out <= reg_out + 'h1;
        end
    end
endmodule
