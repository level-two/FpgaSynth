// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: alu_taylor_calc_1.v
// Description: Module for cosine calculation. Algorithm is based on Taylor 
//              series
//
// Matlab model:
//   fac_nums = zeros(1,11);
//   deriv = [0  1  0 -1  0  1  0 -1  0  1  0 -1];
//   for n = 1:10
//       fac_nums(n) = 1/n;
//   end
//   val = 1;
//   sum = deriv(1);
//   x = pi/2;
//   for n = 1:10
//       a1 = val * fac_nums(n);
//       val = a1 * x;
//       sum = sum + val*deriv(n+1);
//   end
// -----------------------------------------------------------------------------

`include "globals.vh"

module alu_taylor_calc_1 (
    input                    clk        ,
    input                    reset      ,
    input                    do_calc    ,
    input             [ 2:0] func_sel   ,
    input      signed [17:0] xl         ,
    input      signed [17:0] xr         ,
    output reg               calc_done  ,
    output reg signed [17:0] resl       ,
    output reg signed [17:0] resr       ,

    output            [ 7:0] dsp_op     ,
    output     signed [17:0] dsp_al     ,
    output     signed [17:0] dsp_bl     ,
    output     signed [47:0] dsp_cl     ,
    input      signed [47:0] dsp_pl     ,
    output     signed [17:0] dsp_ar     ,
    output     signed [17:0] dsp_br     ,
    output     signed [47:0] dsp_cr     ,
    input      signed [47:0] dsp_pr
);

    // STORE SAMPLE_IN
    reg signed [17:0] xl_reg;
    reg signed [17:0] xr_reg;
    reg        [ 2:0] func_sel_reg;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            xl_reg       <= 18'h00000;
            xr_reg       <= 18'h00000;
            func_sel_reg <= 3'h0;
        end
        else if (do_calc) begin
            xl_reg       <= xl;
            xr_reg       <= xr;
            func_sel_reg <= func_sel;
        end
    end

    // TASKS
    localparam [15:0] NOP              = 16'h0000;
    localparam [15:0] MUL_1_CI_SI      = 16'h0001;
    localparam [15:0] MUL_XA_CI_SI     = 16'h0002;
    localparam [15:0] MUL_SI_1         = 16'h0004;
    localparam [15:0] MUL_SI_AC        = 16'h0008;
    localparam [15:0] MADD_SI_MR_AC    = 16'h0010;
    localparam [15:0] SUB_X_A0_XA      = 16'h0020;
    localparam [15:0] MOV_I_0          = 16'h0040;
    localparam [15:0] INC_I            = 16'h0080;
    localparam [15:0] REPEAT_3         = 16'h0100;
    localparam [15:0] REPEAT_10        = 16'h0200;
    localparam [15:0] MOV_RES_AC       = 16'h0400;
    localparam [15:0] MOV_MR_AC        = 16'h0800;
    localparam [15:0] JP_0             = 16'h1000;
    localparam [15:0] JP_4             = 16'h2000;
    localparam [15:0] WAIT_IN          = 16'h4000;

    reg [15:0] tasks;
    always @(*) begin
        case (pc)
            4'h0   : tasks = WAIT_IN                                           ;

            4'h1   : tasks = SUB_X_A0_XA                                       |
                             MOV_I_0                                           ;
            4'h2   : tasks = REPEAT_3                                          |
                             NOP                                               ;
            4'h3   : tasks = REPEAT_10                                         |
                             ((i_reg == 4'h0) ? MUL_1_CI_SI : MUL_XA_CI_SI)    |
                             ((i_reg == 4'h9) ? MOV_I_0     : INC_I)           ;
            4'h4   : tasks = ((i_reg == 4'h0) ? MUL_SI_1    : MUL_SI_AC)       |
                             MOV_MR_AC                                         ;
            4'h5   : tasks = ((i_reg == 4'h0) ? MUL_SI_1    : MADD_SI_MR_AC)   |
                             INC_I                                             ;
            4'h6   : tasks = ((i_reg != 4'ha) ? JP_4        : NOP)             ;
            4'h7   : tasks = NOP                                               ;
            4'h8   : tasks = MOV_RES_AC                                        |
                             JP_0                                              ;
            default: tasks = JP_0                                              ;
        endcase
    end


    // PC
    reg [3:0] pc;
    always @(posedge reset or posedge clk) begin
        if (reset)
            pc <= 4'h0;
        else if (tasks & JP_0)
            pc <= 4'h0;
        else if (tasks & JP_4)
            pc <= 4'h4;
        else if ((tasks & WAIT_IN   && !do_calc ) ||      
                 (tasks & REPEAT_3  && repeat_st) ||
                 (tasks & REPEAT_10 && repeat_st))
            pc <= pc;
        else
            pc <= pc + 4'h1;
    end


    // REPEAT
    reg  [3:0] repeat_cnt;
    wire [3:0] repeat_cnt_max = (tasks & REPEAT_3 ) ? 4'h2 :
                                (tasks & REPEAT_10) ? 4'h9 : 4'h0;
    wire       repeat_st      = (repeat_cnt != repeat_cnt_max);
    always @(posedge reset or posedge clk) begin
        if (reset)
            repeat_cnt <= 4'h0;
        else if (repeat_cnt == repeat_cnt_max)
            repeat_cnt <= 4'h0;
        else
            repeat_cnt <= repeat_cnt + 4'h1;
    end


    // INDEX REGISTER I
    reg  [3:0] i_reg;
    always @(posedge reset or posedge clk) begin
        if (reset)
            i_reg <= 4'h0;
        else if (tasks & MOV_I_0)
            i_reg <= 4'h0;
        else if (tasks & INC_I)
            i_reg <= i_reg + 4'h1;
    end

    reg signed [17:0] mrl_reg;
    reg signed [17:0] mrr_reg;
    always @(posedge reset or posedge clk) begin
        if (reset)
            mrl_reg <= 18'h00000;
            mrr_reg <= 18'h00000;
        else if (tasks & MOV_MR_AC)
            mrl_reg <= dsp_pl[33:16];
            mrr_reg <= dsp_pr[33:16];
    end


    // Taylor coefficients
    wire signed [17:0] ci;
    wire signed [17:0] a0;
    alu_taylor_coefs_1 alu_taylor_coefs_1 (
        .function_sel (func_sel_reg ),
        .idx          (i_reg        ),
        .deriv_coef   (ci           ),
        .a0           (a0           )
    );


    // MUL TASKS
    wire signed [17:0] sil = sl_reg[i_reg];
    wire signed [17:0] sir = sr_reg[i_reg];
    always @(*) begin
        dsp_op = `DSP_NOP;
        dsp_al     = 18'h00000;
        dsp_ar     = 18'h00000;
        dsp_bl     = 18'h00000;
        dsp_br     = 18'h00000;
        dsp_cl     = 48'h00000;
        dsp_cr     = 48'h00000;

        if (tasks & MUL_1_CI_SI) begin
            dsp_op = `DSP_XIN_MULT | `DSP_ZIN_ZERO;
            dsp_al = ci;
            dsp_ar = ci;
            dsp_bl = 18'h10000;
            dsp_br = 18'h10000;
        end
        else if (tasks & MUL_XA_CI_SI) begin
            dsp_op = `DSP_XIN_MULT | `DSP_ZIN_ZERO;
            dsp_al = ci;
            dsp_ar = ci;
            dsp_bl = xal;
            dsp_br = xar;
        end
        else if (tasks & MUL_SI_1) begin
            dsp_op = `DSP_XIN_MULT | `DSP_ZIN_ZERO;
            dsp_al = sil;
            dsp_ar = sir;
            dsp_bl = 18'h10000;
            dsp_br = 18'h10000;
        end
        else if (tasks & MUL_SI_AC) begin
            dsp_op = `DSP_XIN_MULT | `DSP_ZIN_ZERO;
            dsp_al = sil;
            dsp_ar = sir;
            dsp_bl = dsp_pl[33:16];
            dsp_br = dsp_pr[33:16];
        end
        else if (tasks & MADD_SI_MR_AC) begin
            dsp_op = `DSP_XIN_MULT | `DSP_ZIN_CIN;
            dsp_al = sil;
            dsp_ar = sir;
            dsp_bl = mrl_reg;
            dsp_br = mrr_reg;
            dsp_cl = dsp_pl;
            dsp_cr = dsp_pr;
        end
        else if (tasks & SUB_X_A0_XA) begin
            dsp_op = `DSP_XIN_MULT | `DSP_ZIN_CIN | `DSP_POSTADD_SUB;
            dsl_al = a0;
            dsl_ar = a0;
            dsl_bl = 18'h10000;
            dsl_br = 18'h10000;
            dsl_cl = { {15{xl_reg[17]}}, xl_reg[16:0], 16'h0000};
            dsl_cr = { {15{xr_reg[17]}}, xr_reg[16:0], 16'h0000};
        end
    end
        

    // Array of the intermediate values
    reg [1:0] mov_trig[0:2];
    reg [3:0] mov_idx[0:2];
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            mov_trig[0]     <= 2'b00;
            mov_trig[1]     <= 2'b00;
            mov_trig[2]     <= 2'b00;
            mov_idx [0]     <= 4'h0;
            mov_idx [1]     <= 4'h0;
            mov_idx [2]     <= 4'h0;
        end 
        else begin
            if (tasks & MUL_1_CI_SI) begin
                mov_trig[0] <= 2'b01;
                mov_idx [0] <= i_reg;
            end
            else if (tasks & MUL_XA_CI_SI) begin
                mov_trig[0] <= 2'b01;
                mov_idx [0] <= i_reg;
            end
            else if (tasks & SUB_X_A0_XA) begin
                mov_trig[0] <= 2'b10;
                mov_idx [0] <= 4'h0;
            end
            else begin
                mov_trig[0] <= 2'b00;
            end

            mov_idx [1]     <= mov_idx [0];
            mov_idx [2]     <= mov_idx [1];
            mov_trig[1]     <= mov_trig[0];
            mov_trig[2]     <= mov_trig[1];
        end
    end
    
    reg signed [17:0] xal;
    reg signed [17:0] xar;
    reg signed [17:0] sl_reg[0:9];
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            // do nothing
        end 
        else if (mov_trig[2] == 2'b01)
            sl_reg[mov_idx[2]] <= dsp_pl[33:16];
            sr_reg[mov_idx[2]] <= dsp_pr[33:16];
        else if (mov_trig[2] == 2'b10)
            xal                <= dsp_pl[33:16];
            xar                <= dsp_pr[33:16];
    end


    // MOVE AC VALUE TO RESULTS
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            calc_done <= 1'b0;
            resl      <= 18'h00000;
            resr      <= 18'h00000;
        end
        else if (tasks & MOV_RES_AC) begin
            calc_done <= 1'b1;
            resl      <= dsp_pl[33:16];
            resr      <= dsp_pr[33:16];
        end
        else begin
            calc_done <= 1'b0;
            resl      <= 18'h00000;
            resr      <= 18'h00000;
        end
    end
endmodule

