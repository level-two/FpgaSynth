// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: task_circ_idx_reg.v
// Description: Task for the circular index register
// -----------------------------------------------------------------------------


module task_circ_idx_reg (
    input                    clk,
    input                    reset,
    input                    stb_load,
    input                    stb_inc_circ,
    input                    stb_dec_circ,
    input      [REG_W-1:0]   max_val,
    input      [REG_W-1:0]   reg_in,
    output reg [REG_W-1:0]   reg_out
);

    parameter REG_W = 8;

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            reg_out <= 0;
        end
        else if (stb_load) begin
            reg_out <= reg_in;
        end
        else if (stb_inc_circ) begin
            reg_out <= (reg_out == max_val) ? 0 : reg_out + 'h1;
        end
        else if (stb_dec_circ) begin
            reg_out <= (reg_out == 0) ? max_val : reg_out - 'h1;
        end
    end
endmodule
