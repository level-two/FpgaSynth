// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: module_lpf_params_conv.v
// Description: Converts MIDI CC to the Filter values (omega0, 1/2Q)
//              n = [0-127] --> W = Wmax*2^(-8*n/128) = Wmax*2^(-n/16)
//              W = Wmax * 2^( - floor(n/16) - (n%16)/16 ) = Wmax >> n[6:4] * table_2_pow_minus_n(n[3:0]) 
//              where table_2_pow_minus_n(n[3:0]) = 2^(-n[3:0]/16)
// -----------------------------------------------------------------------------

`include "globals.vh"

module module_lpf_params_conv (
    input                    clk,
    input                    reset,
    input                    do_calc,
    input  [6:0]             cc_omega0,
    input  [6:0]             cc_inv_2q,
    output reg               calc_done,
    output signed [17:0]     omega0,
    output signed [17:0]     inv_2q,

    input  [47:0]            dsp_outs_flat,
    output [91:0]            dsp_ins_flat
);

    localparam signed [17:0] OMEGA0_MAX;


    // STORE SAMPLE_IN
    reg [6:0] cc_omega0_reg;
    reg [6:0] cc_inv_2q_reg;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            cc_omega0_reg <= 18'h00000;
            cc_inv_2q_reg <= 18'h00000;
        end
        else if (do_calc) begin
            cc_omega0_reg <= cc_omega0;
            cc_inv_2q_reg <= cc_inv_2q;
        end
    end


    // TASKS
    localparam [15:0] NOP               = 15'h0000;
    localparam [15:0] WAIT_IN           = 15'h0000;
    localparam [15:0] CAL_COS_W0        = 15'h0000;
    localparam [15:0] WAIT_CAL_DONE     = 15'h0000;
    localparam [15:0] MOV_I_0           = 15'h0000;
    localparam [15:0] INC_I             = 15'h0000;
    localparam [15:0] REPEAT_5          = 15'h0000;
    localparam [15:0] JP_0              = 15'h0000;
    localparam [15:0] MOV_RES_C         = 15'h0000;

    reg [15:0] tasks;
    always @(pc) begin
        case (pc)
            5'h0   : tasks = WAIT_IN           ;
            5'h1   : tasks = CAL_SIN_W0        ;
            5'h2   : tasks = WAIT_CAL_DONE     |
                             MOV_R1_RES        ;
            5'h3   : tasks = CAL_COS_W0        ;
            5'h4   : tasks = WAIT_CAL_DONE     |
                             MOV_R2_RES        ;
            5'h5   : tasks = MUL_R1_INV2Q_C1   ;
            5'h6   : tasks = NOP               ;
            5'h7   : tasks = NOP               ;
            5'h8   : tasks = NOP               ;
            5'h9   : tasks = CAL_INV_1_PLUS_C1 ; 
            5'ha   : tasks = WAIT_CAL_DONE     |
                             MOV_R0_RES        ;
            5'hb   : tasks = SUB_1_R2_C3       ;
            5'hc   : tasks = SUB_C1_1_C1       ;
            5'hd   : tasks = SHLS_R2_C0        ;
            5'he   : tasks = NOP               ;
            5'hf   : tasks = SHRS_C3_C2        |
                             SHRS_C3_C4        |
                             MOV_I_0           ;
            5'h10  : tasks = REPEAT_5          |
                             MUL_CI_R0_CI      |
                             INC_I             ;
            5'h11  : tasks = NOP               ;
            5'h12  : tasks = NOP               ;
            5'h13  : tasks = NOP               ;
            5'h14  : tasks = MOV_RES_C         |
                             JP_0              ;
            default: tasks = JP_0              ;
        endcase
    end


    // PC
    reg [3:0] pc;
    always @(posedge reset or posedge clk) begin
        if (reset)
            pc <= 4'h0;
        else if (tasks & JP_0)
            pc <= 4'h0;
        else if ((tasks & WAIT_IN       && !do_calc ) ||      
                 (tasks & REPEAT_5      && repeat_st) ||
                 (tasks & WAIT_CAL_DONE && !(taylor_calc_done || taylor_1_calc_done)))
            pc <= pc;
        else
            pc <= pc + 4'h1;
    end


    // REPEAT
    reg  [3:0] repeat_cnt;
    wire [3:0] repeat_cnt_max = (tasks & REPEAT_5) ? 4'h4 : 4'h0;
    wire       repeat_st      = (repeat_cnt != repeat_cnt_max);
    always @(posedge reset or posedge clk) begin
        if (reset)
            repeat_cnt <= 4'h0;
        else if (repeat_cnt == repeat_cnt_max)
            repeat_cnt <= 4'h0;
        else
            repeat_cnt <= repeat_cnt + 4'h1;
    end


    reg signed [17:0] two_invpow_val;
    reg        [3:0]  two_invpow_x;
    always @(two_invpow_x) begin
        case (two_invpow_x)
            4'h0   : begin two_invpow_val <= 18'h10000; end
            4'h1   : begin two_invpow_val <= 18'h07a92; end
            4'h2   : begin two_invpow_val <= 18'h07560; end
            4'h3   : begin two_invpow_val <= 18'h07066; end
            4'h4   : begin two_invpow_val <= 18'h06ba2; end
            4'h5   : begin two_invpow_val <= 18'h06712; end
            4'h6   : begin two_invpow_val <= 18'h062b3; end
            4'h7   : begin two_invpow_val <= 18'h05e84; end
            4'h8   : begin two_invpow_val <= 18'h05a82; end
            4'h9   : begin two_invpow_val <= 18'h056ac; end
            4'ha   : begin two_invpow_val <= 18'h052ff; end
            4'hb   : begin two_invpow_val <= 18'h04f7a; end
            4'hc   : begin two_invpow_val <= 18'h04c1b; end
            4'hd   : begin two_invpow_val <= 18'h048e1; end
            4'he   : begin two_invpow_val <= 18'h045ca; end
            4'hf   : begin two_invpow_val <= 18'h042d5; end
            default: begin two_invpow_val <= 18'h00000; end
        endcase
    end


    // MUL TASKS
    wire signed [17:0] ci  = c_reg[i_reg];
    always @(*) begin
        opmode = `DSP_NOP;
        a      = 18'h00000;
        b      = 18'h00000;
        c      = 48'h00000;
        if (tasks & MUL_R1_INV2Q_C1) begin
            opmode = `DSP_XIN_MULT | `DSP_ZIN_ZERO;
            a      = r_reg[1];
            b      = inv_2q_reg;
        end
        else if (tasks & MUL_CI_R0_CI) begin
            opmode = `DSP_XIN_MULT | `DSP_ZIN_ZERO;
            a      = r_reg[0];
            b      = ci;
        end
        else if (tasks & SUB_C1_1_C1) begin
            opmode = `DSP_XIN_MULT | `DSP_ZIN_CIN | `DSP_POSTADD_SUB;
            a      = 18'h10000;
            b      = 18'h10000;
            c      = { {15{c_reg[1][17]}}, c_reg[1][16:0], 16'h0000};
        end
        else if (tasks & SUB_1_R2_C3) begin
            opmode = `DSP_XIN_MULT | `DSP_ZIN_CIN | `DSP_POSTADD_SUB;
            a      = r_reg[2];
            b      = 18'h10000;
            c      = {14'h0000, 18'h10000, 16'h0000};
        end
    end
        

    // Array of the intermediate values
    reg       mov_c_trig[0:2];
    reg [3:0] mov_c_idx[0:2];
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            mov_c_trig[0] <= 1'b0;
            mov_c_trig[1] <= 1'b0;
            mov_c_trig[2] <= 1'b0;
            mov_c_idx [0] <= 4'h0;
            mov_c_idx [1] <= 4'h0;
            mov_c_idx [2] <= 4'h0;
        end 
        else begin
            if (tasks & MUL_CI_R0_CI) begin
                mov_c_trig[0] <= 1'b1;
                mov_c_idx [0] <= i_reg;
            end
            else if (tasks & MUL_R1_INV2Q_C1) begin
                mov_c_trig[0] <= 1'b1;
                mov_c_idx [0] <= 4'h1;
            end
            else if (tasks & SUB_C1_1_C1) begin
                mov_c_trig[0] <= 1'b1;
                mov_c_idx [0] <= 4'h1;
            end
            else if (tasks & SUB_1_R2_C3) begin
                mov_c_trig[0] <= 1'b1;
                mov_c_idx [0] <= 4'h3;
            end
            else begin
                mov_c_trig[0] <= 1'b0;
            end

            mov_c_idx [1] <= mov_c_idx [0];
            mov_c_idx [2] <= mov_c_idx [1];
            mov_c_trig[1] <= mov_c_trig[0];
            mov_c_trig[2] <= mov_c_trig[1];
        end
    end
    


    // DSP signals
    reg         [7:0]  opmode;
    reg  signed [17:0] a;
    reg  signed [17:0] b;
    reg  signed [47:0] c;
    wire signed [47:0] p;

    // Gather local DSP signals 
    assign dsp_ins_flat[91:0] = {opmode, a, b, c};
    assign p = dsp_outs_flat;


    // MOVE AC VALUE TO RESULTS
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            calc_done <= 1'b0;
            coefs_flat<= 90'h0;
        end
        else if (tasks & MOV_RES_C) begin
            calc_done  <= 1'b1;
            // lpf expects coefs in the order {a2,a1,b2,b1,b0}
            coefs_flat <= {c_reg[1], c_reg[0], c_reg[4], c_reg[3], c_reg[2]};
        end
        else begin
            calc_done <= 1'b0;
            coefs_flat<= 90'h0;
        end
    end
endmodule

