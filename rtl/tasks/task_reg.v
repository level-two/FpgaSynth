// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: task_reg.v
// Description: Task for the register
// -----------------------------------------------------------------------------


module task_reg (
    input                    clk,
    input                    reset,
    input                    wr_stb,
    input      [REG_W-1:0]   data_in,
    output reg [REG_W-1:0]   data_out
);

    parameter REG_W      = 18;

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            data_out <= {REG_W{1'b0}};
        end
        else if (tasks & TASK_WR) begin
            data_out <= data_in;
        end
    end
endmodule
