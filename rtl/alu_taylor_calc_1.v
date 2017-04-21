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
    input                    clk,
    input                    reset,
    input                    do_calc,
    input [2:0]              func_sel,
    input signed [17:0]      x_in,
    output reg               calc_done,
    output reg signed [17:0] result,

    input  [83:0]            dsp_outs_flat,
    output [91:0]            dsp_ins_flat
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
    localparam [15:0] MUL_1_CI_SI      = 16'h0001;
    localparam [15:0] MUL_XA_CI_SI     = 16'h0002;
    localparam [15:0] MUL_SI_1_AS      = 16'h0004;
    localparam [15:0] MUL_SI_SIM1_AC   = 16'h0008;
    localparam [15:0] SUB_X_A0_XA      = 16'h0010;
    localparam [15:0] MOV_I_0          = 16'h0020;
    localparam [15:0] INC_I            = 16'h0040;
    localparam [15:0] REPEAT_3         = 16'h0080;
    localparam [15:0] REPEAT_10        = 16'h0100;
    localparam [15:0] MOV_RES_AC       = 16'h0200;
    localparam [15:0] JP_0             = 16'h0400;
    localparam [15:0] WAIT_IN          = 16'h0800;

    reg [15:0] tasks;
    always @(*) begin
        case (pc)
            4'h0   : tasks = WAIT_IN         ;
            4'h1   : tasks = SUB_X_A0_XA     |
                             MOV_I_0         ;
            4'h2   : tasks = REPEAT_3        |
                             NOP             ;
            4'h3   : tasks = REPEAT_10       |
                             ((i_reg == 0) ? MUL_1_CI_SI : MUL_XA_CI_SI) |
                             ((i_reg == 9) ? MOV_I_0 : INC_I);
            4'h4   : tasks = REPEAT_10       |
                             ((i_reg == 0) ? MUL_SI_1_AS : MUL_SI_SIM1_AC) |
                             INC_I           ;
            4'h5   : tasks = REPEAT_3        |
                             NOP             ;
            4'h6   : tasks = MOV_RES_AC      |
                             JP_0            ;
            default: tasks = JP_0            ;
        endcase
    end


    // PC
    reg [3:0] pc;
    always @(posedge reset or posedge clk) begin
        if (reset)
            pc <= 4'h0;
        else if (tasks & JP_0)
            pc <= 4'h0;
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
    wire signed [17:0] si   = s_reg[i_reg];
    wire signed [17:0] sim1 = s_reg[i_reg-4'h1];
    always @(*) begin
        opmode = `DSP_NOP;
        a      = 18'h00000;
        b      = 18'h00000;
        c      = 48'h00000;
        if (tasks & MUL_1_CI_SI) begin
            a      = ci;
            b      = 18'h10000;
        end
        else if (tasks & MUL_XA_CI_SI) begin
            a      = ci;
            b      = xa;
        end
        else if (tasks & MUL_SI_1_AS) begin
            opmode = `DSP_XIN_MULT | `DSP_ZIN_ZERO;
            a      = si;
            b      = 18'h10000;
        end
        else if (tasks & MUL_SI_SIM1_AC) begin
            opmode = `DSP_XIN_MULT | `DSP_ZIN_POUT;
            a      = si;
            b      = sim1;
        end
        else if (tasks & SUB_X_A0_XA) begin
            opmode = `DSP_XIN_MULT | `DSP_ZIN_CIN | `DSP_POSTADD_SUB;
            a      = x_reg;
            b      = 18'h10000;
            c      = {30'h0, a0};
        end
    end
        

    // Array of the intermediate values
    reg [1:0] mov_trig[0:2];
    reg [3:0] mov_idx[0:1];
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            mov_trig[0] <= 2'b00;
            mov_trig[1] <= 2'b00;
            mov_idx [0] <= 4'h0;
            mov_idx [1] <= 4'h0;
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

            mov_idx [1] <= mov_idx [0];
            mov_trig[1] <= mov_trig[0];
            mov_trig[2] <= mov_trig[1];
        end
    end
    
    reg signed [17:0] xa;
    reg signed [17:0] s_reg[0:9];
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            // do nothing
        end 
        else if (mov_trig[1] == 2'b01)
            s_reg[mov_idx[1]] <= m[33:16];
        else if (mov_trig[2] == 2'b10)
            xa <= p[33:16];
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
    reg  signed [47:0] c;
    wire signed [47:0] p;
    wire signed [35:0] m;

    // Gather local DSP signals 
    assign dsp_ins_flat[91:0] = {opmode, a, b, c};
    assign { m, p }           = dsp_outs_flat;
endmodule

