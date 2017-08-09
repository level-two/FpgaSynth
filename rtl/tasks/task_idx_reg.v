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
    input      [TASKS_W-1:0] tasks,
    input      [REG_W-1:0]   reg_in,
    output reg [REG_W-1:0]   reg_out
);

    parameter REG_W      = 18;
    parameter TASKS_W    = 16;
    parameter TASK_LOAD  = 0;
    parameter TASK_INC   = 0;

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            reg_out <= {REG_W{1'b0}};
        end
        else if (tasks & TASK_LOAD) begin
            reg_out <= reg_in;
        end
        else if (tasks & TASK_INC) begin
            reg_out <= reg_out + 'h1;
        end
    end
endmodule
