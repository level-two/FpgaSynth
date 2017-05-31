// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: interpolator_2x.v
// Description: IIR implementation based on Xilinx DSP48A1
// -----------------------------------------------------------------------------

`include "globals.vh"

module interpolator_2x (
    input                    clk,
    input                    reset,
    input                    is_next_busy,
    input                    sample_in_rdy,
    input  signed [17:0]     sample_in_l,
    input  signed [17:0]     sample_in_r,

    output reg               busy,
    output reg               sample_out_rdy,
    output reg signed [17:0] sample_out_l,
    output reg signed [17:0] sample_out_r,

    input  [47:0]            dsp_outs_flat_l,
    input  [47:0]            dsp_outs_flat_r,
    output [91:0]            dsp_ins_flat_l,
    output [91:0]            dsp_ins_flat_r
);


    // STORE SAMPLE_IN
    reg signed [17:0] sample_in_reg_l;
    reg signed [17:0] sample_in_reg_r;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            sample_in_reg_l <= 18'h00000;
            sample_in_reg_r <= 18'h00000;
        end
        else if (sample_in_rdy) begin
            sample_in_reg_l <= sample_in_l;
            sample_in_reg_r <= sample_in_r;
        end
    end


    // TASKS
    localparam [15:0] NOP             = 16'h0;
    localparam [15:0] WAIT_IN         = 16'h1;
    localparam [15:0] WAIT_NEXT_READY = 16'h2;
    localparam [15:0] SET_BUSY        = 16'h4;
    localparam [15:0] RESET_BUSY      = 16'h8;
    localparam [15:0] PUSH_X          = 16'h10;
    localparam [15:0] MOV_I_0         = 16'h20;
    localparam [15:0] INC_I           = 16'h40;
    localparam [15:0] MOV_J_XHEAD     = 16'h80;
    localparam [15:0] INC_J_CIRC      = 16'h100;
    localparam [15:0] MAC_CI_XJ       = 16'h200;
    localparam [15:0] MOV_RES_AC      = 16'h400;
    localparam [15:0] MOV_RES_05_XMID = 16'h800;
    localparam [15:0] REPEAT_3        = 16'h1000;
    localparam [15:0] REPEAT_32       = 16'h2000;
    localparam [15:0] JP_0            = 16'h4000;

    reg [15:0] tasks;
    always @(pc) begin
        case (pc)
            4'h0   : tasks = WAIT_IN         ;
            4'h1   : tasks = SET_BUSY        ;
                             PUSH_X          ;
            4'h2   : tasks = MOV_I_0         |
                             MOV_J_XHEAD     ;
            4'h3   : tasks = REPEAT_32       |
                             MAC_CI_XJ       |
                             INC_I           |
                             INC_J_CIRC      ;
            4'h4   : tasks = REPEAT_3        |
                             NOP             ;
            4'h5   : tasks = MOV_RES_AC      ;
            4'h6   : tasks = WAIT_NEXT_READY ;
            4'h7   : tasks = MOV_RES_05_XMID ;
            4'h8   : tasks = WAIT_NEXT_READY ;
            4'h9   : tasks = JP_0            ;
            default: tasks = JP_0            ;
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
        else if ((tasks & WAIT_IN   && !sample_in_rdy) ||
                 (tasks & REPEAT_3  && repeat_st     ))
                 (tasks & REPEAT_32 && repeat_st     ))
        begin
            pc <= pc;
        end
        else begin
            pc <= pc + 4'h1;
        end
    end


    // REPEAT
    reg  [4:0] repeat_cnt;
    wire [4:0] repeat_cnt_max = (tasks & REPEAT_3 ) ? 5'h2  :
                                (tasks & REPEAT_32) ? 5'h1f : 5'h0;
    wire       repeat_st      = (repeat_cnt != repeat_cnt_max);
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            repeat_cnt <= 5'h0;
        end
        else if (repeat_cnt == repeat_cnt_max) begin
            repeat_cnt <= 5'h0;
        end
        else begin
            repeat_cnt <= repeat_cnt + 5'h1;
        end
    end


    // INDEX REGISTER I
    reg  [4:0] i_reg;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            i_reg <= 5'h0;
        end
        else if (tasks & MOV_I_0) begin
            i_reg <= 5'h0;
        end
        else if (tasks & INC_I) begin
            i_reg <= i_reg + 5'h1;
        end
    end

    reg  [4:0] j_reg;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            j_reg <= 5'h0;
        end
        else if (tasks & MOV_J_XHEAD) begin
            j_reg <= x_buf_head_cnt;
        end
        else if (tasks & INC_I) begin
            j_reg <= j_reg + 5'h1;
        end
    end



    // XY DELAY LINE
    reg signed [17:0] x_buf[0:31];
    reg        [4:0]  x_buf_head_cnt;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            x_buf_head_cnt <= 5'h00
        end
        else if (tasks & PUSH_X) begin
            x_buf_head_cnt <= x_buf_head_cnt + 5'h1
            xbuf[x_buf_head_cnt] <= ;
            // TODO With parametrization!!!!
        end
    end


    // Coefficients
    wire signed [17:0] coefs[0:31];

    // TODO



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
            sample_out     <= p[36:34] == 3'h0 ? p[33:16] :
                              p[36:34] == 3'h7 ? p[33:16] :
                              xy_dly_line[3];
        end
        else begin
            sample_out_rdy <= 1'b0;
            sample_out     <= 18'h00000;
        end
    end


    // DSP signals
    reg         [7:0]  opmode;
    reg  signed [17:0] al;
    reg  signed [17:0] ar;
    reg  signed [17:0] bl;
    reg  signed [17:0] br;
    wire signed [47:0] c_nc = 48'b0;
    wire signed [47:0] pl;
    wire signed [47:0] pr;

    // Gather local DSP signals 
    assign dsp_ins_flat_l[91:0] = {opmode, al, bl, c_nc};
    assign dsp_ins_flat_r[91:0] = {opmode, ar, br, c_nc};
    assign pl = dsp_outs_flat_l;
    assign pr = dsp_outs_flat_r;
endmodule
