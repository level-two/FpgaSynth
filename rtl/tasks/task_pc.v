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
    output reg [PC_W-1:0]    pc_out
);

    parameter PC_W       = 4;
    parameter TASKS_W    = 16;

    parameter TASK_JP0   = 0;
    parameter TASK_JP1   = 0;
    parameter TASK_JP2   = 0;
    parameter TASK_JP3   = 0;

    parameter JP_ADDR0   = 0;
    parameter JP_ADDR1   = 0;
    parameter JP_ADDR2   = 0;
    parameter JP_ADDR3   = 0;

    parameter TASK_JPS0  = 0;
    parameter TASK_JPS1  = 0;
    parameter TASK_JPS2  = 0;
    parameter TASK_JPS3  = 0;


    always @(posedge reset or posedge clk) begin
        if (reset) begin
            pc_out <= {PC_W{1'b0}};
        end
        else if (TASK_JP0 != 0 && tasks & TASK_JP0) begin
            pc_out <= JP_ADDR0;
        end
        else if (TASK_JP1 != 0 && tasks & TASK_JP1) begin
            pc_out <= JP_ADDR1;
        end
        else if (TASK_JP2 != 0 && tasks & TASK_JP2) begin
            pc_out <= JP_ADDR2;
        end
        else if (TASK_JP3 != 0 && tasks & TASK_JP3) begin
            pc_out <= JP_ADDR3;
        end
        else if (TASK_JPS0 != 0 && tasks & TASK_JPS0) begin
            pc_out <= pc_out;
        end
        else if (TASK_JPS1 != 0 && tasks & TASK_JPS1) begin
            pc_out <= pc_out;
        end
        else if (TASK_JPS2 != 0 && tasks & TASK_JPS2) begin
            pc_out <= pc_out;
        end
        else if (TASK_JPS3 != 0 && tasks & TASK_JPS3) begin
            pc_out <= pc_out;
        end
        else begin
            pc_out <= pc_out + PC_W'h1;
        end
    end
endmodule
