// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: task_repeat.v
// Description: Task for repeating
// -----------------------------------------------------------------------------


module task_repeat (
    input                clk,
    input                reset,
    input  [TASKS_W-1:0] tasks,
    output reg           done
);

    parameter  TASKS_W      = 16;
    parameter  TASK_REPEAT  = 0;
    parameter  REPEAT_CNT   = 1;
    localparam CNT_W        = $clog2(REPEAT_CNT);

    reg  [CNT_W-1:0] repeat_cnt;
    wire [CNT_W-1:0] repeat_cnt_max =
        (tasks & TASK_REPEAT) ? REPEAT_CNT-1 :
                                {CNT_W{1'b0}};

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            repeat_cnt <= {CNT_W{1'b0}};
            done       <= 1'b0;
        end
        else if (repeat_cnt == repeat_cnt_max) begin
            repeat_cnt <= {CNT_W{1'b0}};
            done       <= 1'b1;
        end
        else begin
            repeat_cnt <= repeat_cnt + { {CNT_W-1{1'b0}}. 1'b1};
            done       <= 1'b0;
        end
    end
endmodule
