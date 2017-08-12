// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: task_dsp.v
// Description: Task for the DSP
// -----------------------------------------------------------------------------


module task_dsp (
    input                clk,
    input                reset,
    input  [TASKS_W-1:0] tasks,
    input  [17:0]        a_in,
    input  [17:0]        b_in,
    input  [47:0]        c_in,
    output [17:0]        reg_out,
    output               done,

    // DSP signals
    input  [47:0]        dsp_outs_flat,
    output [91:0]        dsp_ins_flat
);

    parameter TASKS_W    = 16;
    parameter TASK_MUL   = 0;
    parameter TASK_MAC   = 0;
    parameter TASK_MAD   = 0;
    parameter TASK_MSB   = 0;

    wire is_task_fired = (tasks & TASK_MUL) ? 1'b1 :
                         (tasks & TASK_MAC) ? 1'b1 :
                         (tasks & TASK_MAD) ? 1'b1 :
                         (tasks & TASK_MSB) ? 1'b1 :
                         1'b0;

    wire [7:0]  opmode =
        (tasks & TASK_MUL) ? `DSP_XIN_MULT | `DSP_ZIN_ZERO :
        (tasks & TASK_MAC) ? `DSP_XIN_MULT | `DSP_ZIN_POUT :
        (tasks & TASK_MAD) ? `DSP_XIN_MULT | `DSP_ZIN_CIN | `DSP_POSTADD_ADD :
        (tasks & TASK_MSB) ? `DSP_XIN_MULT | `DSP_ZIN_CIN | `DSP_POSTADD_SUB :
         `DSP_NOP;

    assign dsp_ins_flat[91:0] <=
        is_task_fired ? { opmode, a_in, b_in, c_in } : 92'b0;

    reg [2:0] stb_dly_line;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            stb_dly_line <= 3'h0;
        end
        else begin
            stb_dly_line[2:0] <= { stb_dly_line[1:0], is_task_fired };
        end
    end

    assign done    = stb_dly_line[2];
    assign reg_out = stb_dly_line[2] ? dsp_outs_flat[33:16] : 18'b0;

endmodule
