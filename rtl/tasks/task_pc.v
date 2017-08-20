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
    input                    jp_stb,
    input      [PC_W-1:0]    jp_addr,
    output reg [PC_W-1:0]    pc_out
);

    parameter PC_W = 4;

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            pc_out <= 0;
        end
        else if (jp_stb) begin
            pc_out <= jp_addr;
        end
        else begin
            pc_out <= pc_out + 1;
        end
    end
endmodule
