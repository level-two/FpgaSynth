// -----------------------------------------------------------------------------
// Copyright � 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: module_lpf_coefs_calc.v
// Description: Module for calculation of coefficients for LPF based on IIR
// -----------------------------------------------------------------------------

`include "globals.vh"

module module_lpf_coefs_calc (
    input                    clk,
    input                    reset,
    input signed [17:0]      omega0,
    input signed [17:0]      inv_2q,
    input                    do_calc,
    output reg [18*5-1:0]    coefs_flat,
    output reg               calc_done,

    input  [47:0]            dsp_outs_flat,
    output [91:0]            dsp_ins_flat
);

    // STORE SAMPLE_IN
    reg signed [17:0] omega0_reg;
    reg signed [17:0] inv_2q_reg;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            omega0_reg <= 18'h00000;
            inv_2q_reg <= 18'h00000;
        end
        else if (do_calc) begin
            omega0_reg <= omega0;
            inv_2q_reg <= inv_2q;
        end
    end


    // TASKS
    localparam [19:0] NOP               = 20'h00000;
    localparam [19:0] CAL_INV_1_PLUS_C1 = 20'h00001;
    localparam [19:0] CAL_SIN_W0        = 20'h00002;
    localparam [19:0] CAL_COS_W0        = 20'h00004;
    localparam [19:0] WAIT_CAL_DONE     = 20'h00008;
    localparam [19:0] MOV_R0_RES        = 20'h00010;
    localparam [19:0] MOV_R1_RES        = 20'h00020;
    localparam [19:0] MOV_R2_RES        = 20'h00040;
    localparam [19:0] MUL_R1_INV2Q_C1   = 20'h00080;
    localparam [19:0] MUL_CI_R0_CI      = 20'h00100;
    localparam [19:0] SUB_C1_1_C1       = 20'h00200;
    localparam [19:0] SUB_1_R2_C3       = 20'h00400;
    localparam [19:0] SHLS_R2_C0        = 20'h00800;
    localparam [19:0] SHRS_C3_C2        = 20'h01000;
    localparam [19:0] SHRS_C3_C4        = 20'h02000;
    localparam [19:0] MOV_I_0           = 20'h04000;
    localparam [19:0] INC_I             = 20'h08000;
    localparam [19:0] REPEAT_5          = 20'h10000;
    localparam [19:0] JP_0              = 20'h20000;
    localparam [19:0] WAIT_IN           = 20'h40000;
    localparam [19:0] MOV_RES_C         = 20'h80000;

    reg [19:0] tasks;
    always @(*) begin
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
    reg [4:0] pc;
    always @(posedge reset or posedge clk) begin
        if (reset)
            pc <= 5'h0;
        else if (tasks & JP_0)
            pc <= 5'h0;
        else if ((tasks & WAIT_IN       && !do_calc ) ||      
                 (tasks & REPEAT_5      && repeat_st) ||
                 (tasks & WAIT_CAL_DONE && !(taylor_calc_done || taylor_1_calc_done)))
            pc <= pc;
        else
            pc <= pc + 5'h1;
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



    // REGISTERS R0-R2
    reg signed [17:0] r_reg[0:2];

    always @(posedge reset or posedge clk) begin
        if (reset)
            r_reg[0] <= 18'h00000;
        else if (tasks & MOV_R0_RES)
            r_reg[0] <= taylor_1_result;
    end

    always @(posedge reset or posedge clk) begin
        if (reset)
            r_reg[1] <= 18'h00000;
        else if (tasks & MOV_R1_RES)
            r_reg[1] <= taylor_result;
    end

    always @(posedge reset or posedge clk) begin
        if (reset)
            r_reg[2] <= 18'h00000;
        else if (tasks & MOV_R2_RES)
            r_reg[2] <= taylor_result;
        else if (tasks & SHLS_R2_C0)
            r_reg[2] <= c_reg[0] <<< 1;
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
    
    reg signed [17:0] c_reg[0:4];

    always @(posedge reset or posedge clk) begin
        if (reset)
            c_reg[0] <= 18'h00000;
        else if (tasks & SHLS_R2_C0)
            c_reg[0] <= r_reg[2] <<< 1;
        else if (mov_c_trig[2] == 1'b1 && mov_c_idx[2] == 4'h0)
            c_reg[0] <= p[33:16];
    end

    always @(posedge reset or posedge clk) begin
        if (reset)
            c_reg[1] <= 18'h00000;
        else if (mov_c_trig[2] == 1'b1 && mov_c_idx[2] == 4'h1)
            c_reg[1] <= p[33:16];
    end

    always @(posedge reset or posedge clk) begin
        if (reset)
            c_reg[2] <= 18'h00000;
        else if (tasks & SHRS_C3_C2)
            c_reg[2] <= c_reg[3] >>> 1;
        else if (mov_c_trig[2] == 1'b1 && mov_c_idx[2] == 4'h2)
            c_reg[2] <= p[33:16];
    end

    always @(posedge reset or posedge clk) begin
        if (reset)
            c_reg[3] <= 18'h00000;
        else if (mov_c_trig[2] == 1'b1 && mov_c_idx[2] == 4'h3)
            c_reg[3] <= p[33:16];
    end

    always @(posedge reset or posedge clk) begin
        if (reset)
            c_reg[4] <= 18'h00000;
        else if (tasks & SHRS_C3_C4)
            c_reg[4] <= c_reg[3] >>> 1;
        else if (mov_c_trig[2] == 1'b1 && mov_c_idx[2] == 4'h4)
            c_reg[4] <= p[33:16];
    end


    // Taylor
    reg                taylor_do_calc;
    reg [2:0]          taylor_function_sel;
    reg  signed [17:0] taylor_x_in;
    wire               taylor_calc_done;
    wire signed [17:0] taylor_result;
    wire [91:0]        taylor_dsp_ins_flat;

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            taylor_do_calc      <= 1'b0;
            taylor_function_sel <= `ALU_TAYLOR_NONE;
            taylor_x_in         <= 18'h00000;
        end
        else if (tasks & CAL_SIN_W0) begin
            taylor_do_calc      <= 1'b1;
            taylor_function_sel <= `ALU_TAYLOR_SIN;
            taylor_x_in         <= omega0_reg;
        end
        else if (tasks & CAL_COS_W0) begin
            taylor_do_calc      <= 1'b1;
            taylor_function_sel <= `ALU_TAYLOR_COS;
            taylor_x_in         <= omega0_reg;
        end
        else begin
            taylor_do_calc      <= 1'b0;
            taylor_function_sel <= 3'b0;
            taylor_x_in         <= 18'h00000;
        end
    end


    alu_taylor_calc alu_taylor_calc (
        .clk            (clk                 ),
        .reset          (reset               ),
        .do_calc        (taylor_do_calc      ),
        .func_sel       (taylor_function_sel ),
        .x_in           (taylor_x_in         ),
        .calc_done      (taylor_calc_done    ),
        .result         (taylor_result       ),
        .dsp_ins_flat   (taylor_dsp_ins_flat ),
        .dsp_outs_flat  (dsp_outs_flat       )
    );



    // Taylor 1
    reg                taylor_1_do_calc;
    reg [2:0]          taylor_1_function_sel;
    reg  signed [17:0] taylor_1_x_in;
    wire               taylor_1_calc_done;
    wire signed [17:0] taylor_1_result;
    wire [91:0]        taylor_1_dsp_ins_flat;

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            taylor_1_do_calc      <= 1'b0;
            taylor_1_function_sel <= `ALU_TAYLOR_NONE;
            taylor_1_x_in         <= 18'h00000;
        end
        else if (tasks & CAL_INV_1_PLUS_C1) begin
            taylor_1_do_calc      <= 1'b1;
            taylor_1_function_sel <= `ALU_TAYLOR_INV_1_PLUS_X;
            taylor_1_x_in         <= c_reg[1];
        end
        else begin
            taylor_1_do_calc      <= 1'b0;
            taylor_1_function_sel <= 3'b0;
            taylor_1_x_in         <= 18'h00000;
        end
    end


    alu_taylor_calc_1 alu_taylor_calc_1 (
        .clk            (clk                   ),
        .reset          (reset                 ),
        .do_calc        (taylor_1_do_calc      ),
        .func_sel       (taylor_1_function_sel ),
        .x_in           (taylor_1_x_in         ),
        .calc_done      (taylor_1_calc_done    ),
        .result         (taylor_1_result       ),
        .dsp_ins_flat   (taylor_1_dsp_ins_flat ),
        .dsp_outs_flat  (dsp_outs_flat         )
    );





    // DSP signals
    reg         [7:0]  opmode;
    reg  signed [17:0] a;
    reg  signed [17:0] b;
    reg  signed [47:0] c;
    wire signed [47:0] p;

    // Gather local DSP signals 
    assign dsp_ins_flat_local[91:0] = {opmode, a, b, c};
    assign p = dsp_outs_flat;

    // DSP signals interconnection
    wire [91:0] dsp_ins_flat_local;
    assign dsp_ins_flat = dsp_ins_flat_local  |
                          taylor_dsp_ins_flat |
                          taylor_1_dsp_ins_flat;


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

