// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: task_pc.v
// Description: Task for the PC register
// -----------------------------------------------------------------------------


module task_pc (
    input                    clk,
    input                    reset,
    input      [TASKS_W-1:0] tasks,
    input      [PC_W-1:0]    jp_addr,
    output reg [PC_W-1:0]    pc_out
);

    parameter PC_W       = 4;
    parameter TASKS_W    = 16;
    parameter TASK_JP    = 0;
    parameter TASK_JPS   = 0;


    always @(posedge reset or posedge clk) begin
        if (reset) begin
            pc_out <= {PC_W{1'b0}};
        end
        else if (TASK_JP != 0 && tasks & TASK_JP) begin
            pc_out <= jp_addr;
        end
        else if (TASK_JPS != 0 && tasks & TASK_JPS) begin
            pc_out <= pc_out;
        end
        else begin
            pc_out <= pc_out + PC_W'h1;
        end
    end
endmodule
