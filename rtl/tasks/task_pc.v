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
    input                    repeat_done,
    output reg [PC_W-1:0]    pc_out
);

    parameter PC_W       = 4;
    parameter TASKS_W    = 16;
    parameter [TASKS_W+PC_W-1:0] TASK_JP[0:3]  = 0;
    parameter TASK_JPS   = 0;


    genvar i;
    generate
        always @(posedge reset or posedge clk) begin
            if (reset) begin
                pc_out <= {PC_W{1'b0}};
            end
            else begin
                bit [PC_W-1:0] next_addr;
                next_addr = pc_out + PC_W'h1;

                for (i = 0; i < 4; i = i+1) begin
                    if ((TASK_JP[i][TASKS_W+PC_W-1:PC_W] != TASKS_W'b0) &&
                        (tasks & TASK_JP[i][TASKS_W+PC_W-1:PC_W])) begin
                        next_addr = TASK_JP[i][PC_W-1:0];
                    end
                end

                if (TASK_JPS != 0 && tasks & TASK_JPS && repeat_done == 1'b0) begin
                    next_addr = pc_out;
                end

                pc_out <= next_addr;
            end
        end
    endgenerate
endmodule
