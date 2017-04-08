// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: alu_taylor_calc.v
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

module alu_taylor_calc (
    input                    clk,
    input                    reset,
    input                    do_calc,
    input [2:0]              func_sel,
    input signed [17:0]      x_in,
    output reg               calc_done,
    output reg signed [17:0] result,

    input  [83:0]            dsp_outs_flat,
    output [43:0]            dsp_ins_flat
);

    // STORE SAMPLE_IN
    reg signed [17:0] x_reg;
    reg        [2:0]  func_sel_reg;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            x_reg        <= 18'h00000;
            func_sel_reg <= 3'h0;
        end
        else if (do_calc) begin
            x_reg        <= x_in;
            func_sel_reg <= func_sel;
        end
    end

    // TASKS
    localparam [15:0] NOP              = 16'h0000;
    localparam [15:0] MUL_X_FJ_VJ      = 16'h0001;
    localparam [15:0] MUL_X_FJ_VJ_AC0  = 16'h0002;
    localparam [15:0] MUL_VI_VJ_VJ     = 16'h0004;
    localparam [15:0] MUL_VI_CI_AC     = 16'h0008;
    localparam [15:0] MOV_V0_1         = 16'h0010;
    localparam [15:0] MOV_I_0          = 16'h0020;
    localparam [15:0] MOV_J_1          = 16'h0040;
    localparam [15:0] INC_I            = 16'h0080;
    localparam [15:0] INC_J            = 16'h0100;
    localparam [15:0] JP_J_N10_UP1     = 16'h0200;
    localparam [15:0] REPEAT_3         = 16'h0400;
    localparam [15:0] REPEAT_10        = 16'h0800;
    localparam [15:0] MOV_RES_AC       = 16'h1000;
    localparam [15:0] JP_1             = 16'h2000;
    localparam [15:0] WAIT_IN          = 16'h4000;

    reg [15:0] tasks;
    always @(pc) begin
        case (pc)
            4'h0   : tasks = MOV_V0_1        ;
            4'h1   : tasks = WAIT_IN         |
                             MOV_J_1         ;
            4'h2   : tasks = REPEAT_10       |
                             MUL_X_FJ_VJ     |
                             INC_J           ;
            4'h3   : tasks = MUL_X_FJ_VJ_AC0 |
                             MOV_I_0         |
                             MOV_J_1         ;
            4'h4   : tasks = MUL_VI_VJ_VJ    ;
            4'h5   : tasks = MUL_VI_CI_AC    |
                             INC_I           |
                             INC_J           |
                             JP_J_N10_UP1    ;
            4'h6   : tasks = NOP             ;
            4'h7   : tasks = MUL_VI_CI_AC    ;
            4'h8   : tasks = REPEAT_3        |
                             NOP             ;
            4'h9   : tasks = MOV_RES_AC      |
                             JP_1            ;
            default: tasks = JP_1            ;
        endcase
    end


    // PC
    reg [3:0] pc;
    always @(posedge reset or posedge clk) begin
        if (reset)
            pc <= 4'h0;
        else if (tasks & JP_1)
            pc <= 4'h1;
        else if ((tasks & WAIT_IN   && !do_calc ) ||      
                 (tasks & REPEAT_3  && repeat_st) ||
                 (tasks & REPEAT_10 && repeat_st))
            pc <= pc;
        else if (tasks & JP_J_N10_UP1 && j_reg != 4'ha)
            pc <= pc - 4'h1;
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


    // INDEX REGISTER J
    reg  [3:0] j_reg;
    always @(posedge reset or posedge clk) begin
        if (reset)
            j_reg <= 4'h0;
        else if (tasks & MOV_J_1)
            j_reg <= 4'h1;
        else if (tasks & INC_J)
            j_reg <= j_reg + 4'h1;
    end


    // Taylor coefficients
    wire signed [17:0] deriv_coef_i;
    alu_taylor_coefs alu_taylor_coefs (
        .function_sel (func_sel_reg ),
        .idx          (i_reg        ),
        .deriv_coef   (deriv_coef_i )
    );


    // Values for factorial calculation
    reg signed [17:0] frac_coef_j;
    always @(j_reg) begin
        case (j_reg)
            4'h0   : frac_coef_j <= 18'h10000; // 1
            4'h1   : frac_coef_j <= 18'h10000; // 1
            4'h2   : frac_coef_j <= 18'h08000; // 1/2
            4'h3   : frac_coef_j <= 18'h05555; // 1/3
            4'h4   : frac_coef_j <= 18'h04000; // 1/4
            4'h5   : frac_coef_j <= 18'h03333; // 1/5
            4'h6   : frac_coef_j <= 18'h02aab; // 1/6
            4'h7   : frac_coef_j <= 18'h02492; // 1/7
            4'h8   : frac_coef_j <= 18'h02000; // 1/8
            4'h9   : frac_coef_j <= 18'h01c72; // 1/9
            4'ha   : frac_coef_j <= 18'h0199a; // 1/10
            default: frac_coef_j <= 18'h00000;
        endcase
    end


    // MUL TASKS
    wire signed [17:0] fj  = frac_coef_j;
    wire signed [17:0] ci  = deriv_coef_i;
    wire signed [17:0] vi  = val[i_reg];
    wire signed [17:0] vj  = val[j_reg];

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            opmode <= `DSP_NOP;
            a      <= 18'h00000;
            b      <= 18'h00000;
        end
        else if (tasks & MUL_X_FJ_VJ) begin
            opmode <= `DSP_XIN_ZERO | `DSP_ZIN_POUT;
            a      <= x_reg;
            b      <= fj;
        end
        else if (tasks & MUL_X_FJ_VJ_AC0) begin
            opmode <= `DSP_XIN_ZERO | `DSP_ZIN_ZERO;
            a      <= x_reg;
            b      <= fj;
        end
        else if (tasks & MUL_VI_VJ_VJ) begin
            opmode <= `DSP_XIN_ZERO | `DSP_ZIN_POUT;
            a      <= vi;
            b      <= vj;
        end
        else if (tasks & MUL_VI_CI_AC) begin
            opmode <= `DSP_XIN_MULT | `DSP_ZIN_POUT;
            a      <= vi;
            b      <= ci;
        end
        else begin
            opmode <= `DSP_NOP;
            a      <= 18'h00000;
            b      <= 18'h00000;
        end
    end
        

    // Array of the intermediate values
    reg       mov_val_m_trig[0:1];
    reg [3:0] mov_val_m_idx[0:1];

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            mov_val_m_trig[0] <= 1'b0;
            mov_val_m_trig[1] <= 1'b0;
            mov_val_m_idx [0] <= 4'h0;
            mov_val_m_idx [1] <= 4'h0;
        end 
        else begin
            if ((tasks & MUL_X_FJ_VJ)   ||
                (tasks & MUL_VI_VJ_VJ)  ||
                (tasks & MUL_X_FJ_VJ_AC0))
            begin
                mov_val_m_trig[0] <= 1'b1;
            end
            else begin
                mov_val_m_trig[0] <= 1'b0;
            end

            mov_val_m_idx [0] <= j_reg;
            mov_val_m_idx [1] <= mov_val_m_idx [0];
            mov_val_m_trig[1] <= mov_val_m_trig[0];
        end
    end
    
    reg signed [17:0] val[0:10];
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            // do nothing
        end 
        else if (tasks & MOV_V0_1) begin
            val[0] <= 18'h10000;
        end
        else if (mov_val_m_trig[1] == 1'b1) begin
            val[mov_val_m_idx[1]] <= m[33:16];
        end
    end


    // MOVE AC VALUE TO RESULTS
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            calc_done <= 1'b0;
            result    <= 18'h00000;
        end
        else if (tasks & MOV_RES_AC) begin
            calc_done <= 1'b1;
            result    <= p[33:16];
        end
        else begin
            calc_done <= 1'b0;
            result    <= 18'h00000;
        end
    end


    // DSP signals
    reg         [7:0]  opmode;
    reg  signed [17:0] a;
    reg  signed [17:0] b;
    wire signed [47:0] p;
    wire signed [35:0] m;

    // Gather local DSP signals 
    assign dsp_ins_flat[43:0] = { opmode, a, b };
    assign { m, p }           = dsp_outs_flat;
endmodule

