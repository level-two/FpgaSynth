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
    input                stb,
    input  [17:0]        a_in,
    input  [17:0]        b_in,
    input  [47:0]        c_in,
    input  [7:0]         opmode,
    output [17:0]        result,
    output               done,

    // DSP signals
    input  [47:0]        dsp_outs_flat,
    output [91:0]        dsp_ins_flat
);

    assign dsp_ins_flat[91:0] <= stb ? { opmode, a_in, b_in, c_in } : 92'b0;

    reg [2:0] stb_dly_line;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            stb_dly_line <= 3'h0;
        end
        else begin
            stb_dly_line[2:0] <= { stb_dly_line[1:0], is_task_fired };
        end
    end

    assign done   = stb_dly_line[2];
    assign result = done ? dsp_outs_flat[33:16] : 18'b0;
endmodule
