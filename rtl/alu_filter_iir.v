// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: alu_filter_iir.v
// Description: IIR implementation based on Xilinx DSP48A1
// -----------------------------------------------------------------------------

`include "globals.vh"

module alu_filter_iir (
    input                    clk,
    input                    reset,
    input  [5*18-1:0]        coefs_flat,
    input  signed [17:0]     sample_in,
    input                    sample_in_rdy,
    output reg signed [17:0] sample_out,
    output reg               sample_out_rdy,

    input  [47:0]            dsp_outs_flat,
    output [91:0]            dsp_ins_flat
);


    // STORE SAMPLE_IN
    reg signed [17:0] sample_in_reg;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            sample_in_reg <= 18'h00000;
        end
        else if (sample_in_rdy) begin
            sample_in_reg <= sample_in;
        end
    end


    // TASKS
    localparam [15:0] NOP            = 16'h0000;
    localparam [15:0] MUL_CI_IN_AS   = 16'h0001;
    localparam [15:0] MUL_CI_XYI_AC  = 16'h0002;
    localparam [15:0] MOV_I_0        = 16'h0004;
    localparam [15:0] INC_I          = 16'h0008;
    localparam [15:0] MOV_RES_AC     = 16'h0010;
    localparam [15:0] PUSH_X_IN      = 16'h0020;
    localparam [15:0] PUSH_Y_AC      = 16'h0040;
    localparam [15:0] REPEAT_3       = 16'h0080;
    localparam [15:0] CAL_COEFS      = 16'h0100;
    localparam [15:0] CAL_COEFS_WAIT = 16'h0200;
    localparam [15:0] JP_0           = 16'h0400;
    localparam [15:0] WAIT_IN        = 16'h0800;
              
    reg [15:0] tasks;
    always @(pc) begin
        case (pc)
            4'h0   : tasks = WAIT_IN       ;
            4'h1   : tasks = PUSH_X_IN     |
                             MUL_CI_IN_AS  |
                             INC_I         ;
            4'h2   : tasks = REPEAT_3      |
                             MUL_CI_XYI_AC |
                             INC_I         ;
            4'h3   : tasks = MUL_CI_XYI_AC |
                             MOV_I_0       ;
            4'h4   : tasks = REPEAT_3      |
                             NOP           ;
            4'h5   : tasks = MOV_RES_AC    |
                             PUSH_Y_AC     |
                             JP_0          ;
            default: tasks = JP_0          ;
        endcase
    end


    // PC
    reg [3:0] pc;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            pc <= 4'h0;
        end
        else if (tasks & JP_0) begin
            pc <= 4'h0;
        end
        else if ((tasks & WAIT_IN  && !sample_in_rdy) ||      
                 (tasks & REPEAT_3 && repeat_st     ))
        begin
            pc <= pc;
        end
        else begin
            pc <= pc + 4'h1;
        end
    end


    // REPEAT
    reg  [3:0] repeat_cnt;
    wire [3:0] repeat_cnt_max = (tasks & REPEAT_3) ? 4'h2 : 4'h0;
    wire       repeat_st      = (repeat_cnt != repeat_cnt_max);
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            repeat_cnt <= 4'h0;
        end
        else if (repeat_cnt == repeat_cnt_max) begin
            repeat_cnt <= 4'h0;
        end
        else begin
            repeat_cnt <= repeat_cnt + 4'h1;
        end
    end


    // INDEX REGISTER I
    reg  [3:0] i_reg;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            i_reg <= 4'h0;
        end
        else if (tasks & MOV_I_0) begin
            i_reg <= 4'h0;
        end
        else if (tasks & INC_I) begin
            i_reg <= i_reg + 4'h1;
        end
    end


    // XY DELAY LINE
    reg  signed [17:0] xy_dly_line[0:4];
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            xy_dly_line[0] <= 18'h00000;
            xy_dly_line[1] <= 18'h00000;
            xy_dly_line[2] <= 18'h00000;
            xy_dly_line[3] <= 18'h00000;
            xy_dly_line[4] <= 18'h00000;
        end
        else if (tasks & PUSH_X_IN) begin
            xy_dly_line[0] <= sample_in_reg;
            xy_dly_line[1] <= xy_dly_line[0];
            xy_dly_line[2] <= xy_dly_line[1];
        end
        else if (tasks & PUSH_Y_AC) begin
            xy_dly_line[3] <= p[33:16];
            xy_dly_line[4] <= xy_dly_line[3];
        end
    end


    // Coefficients
    wire signed [17:0] coefs[0:4];
    assign coefs[0] = 18'h0009b;
    assign coefs[1] = 18'h00137;
    assign coefs[2] = 18'h0009b;
    assign coefs[3] = 18'h1e538;
    assign coefs[4] = 18'h31858;

    /*
    genvar i;
    generate
        for (i = 0; i < 5; i=i+1) begin : COEFS_BLK
            assign coefs[i] = coefs_flat[18*i +: 18];
        end
    endgenerate
    */


    // MUL TASKS
    wire signed [17:0] ci  = coefs[i_reg];
    wire signed [17:0] xyi = xy_dly_line[i_reg];
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            opmode <= `DSP_NOP;
            a      <= 18'h00000;
            b      <= 18'h00000;
        end
        else if (tasks & MUL_CI_IN_AS) begin
            opmode <= `DSP_XIN_MULT | `DSP_ZIN_ZERO;
            a      <= ci;
            b      <= sample_in_reg;
        end
        else if (tasks & MUL_CI_XYI_AC) begin
            opmode <= `DSP_XIN_MULT | `DSP_ZIN_POUT;
            a      <= ci;
            b      <= xyi;
        end
        else begin
            opmode <= `DSP_NOP;
            a      <= 18'h00000;
            b      <= 18'h00000;
        end
    end


    // MOVE AC VALUE TO RESULTS
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            sample_out_rdy <= 1'b0;
            sample_out     <= 18'h00000;
        end
        else if (tasks & MOV_RES_AC) begin
            sample_out_rdy <= 1'b1;
            sample_out     <= p[33:16];
        end
        else begin
            sample_out_rdy <= 1'b0;
            sample_out     <= 18'h00000;
        end
    end


    // DSP signals
    reg         [7:0]  opmode;
    reg  signed [17:0] a;
    reg  signed [17:0] b;
    wire signed [47:0] c_nc = 48'b0;
    wire signed [47:0] p;

    // Gather local DSP signals 
    assign dsp_ins_flat[91:0] = {opmode, a, b, c_nc};
    assign p = dsp_outs_flat;

endmodule
