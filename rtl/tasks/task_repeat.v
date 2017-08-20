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
    input             clk,
    input             reset,
    input             repeat_stb,
    input [CNT_W-1:0] repeat_cnt,
    output            is_repeating,
    output            is_done
);

    parameter CNT_W = 4;

    wire [CNT_W-1:0] repeat_cnt_max = repeat_stb ? repeat_cnt-1 : 0;
    reg  [CNT_W-1:0] cnt_val;

    assign is_done      = (cnt_val == repeat_cnt_max);
    assign is_repeating = (repeat_cnt_max != 0) && !is_done;

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            cnt_val <= 0;
        end
        else if (is_done) begin
            cnt_val <= 0;
        end
        else if (is_repeating) begin
            cnt_val <= cnt_val + 1;
        end
        else begin
            cnt_val <= 0;
        end
    end
endmodule
