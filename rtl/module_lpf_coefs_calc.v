// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
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
    input signed [17:0]      inv_2Q,
    input                    do_calc,
    output reg [18*5-1:0]    coefs_flat,
    output reg               calc_done,

    input  [83:0]            dsp_outs_flat,
    output [43:0]            dsp_ins_flat
);


/*
// STUB
    assign dsp_ins_flat = 44'h0;

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            coefs_flat <= 90'h0;
            calc_done  <= 1'b0;
        end
        else begin
            calc_done  <= do_calc;
            if (do_calc) begin
                coefs_flat <= {3{$random()}};
            end
        end
    end
*/


    // TASKS
    localparam [15:0] NOP               = 16'h0000;

    localparam [15:0] CAL_INV_1_PLUS_R1 = 16'h0001;
    localparam [15:0] CAL_SIN_W0        = 16'h0001;
    localparam [15:0] CAL_COS_W0        = 16'h0001;
    localparam [15:0] WAIT_CAL_DONE     = 16'h0001;
    localparam [15:0] MOV_R0_RES        = 16'h0001;
    localparam [15:0] MOV_R2_RES        = 16'h0001;
    localparam [15:0] MOV_R3_RES        = 16'h0001;

    localparam [15:0] MUL_R2_INVQ_R1    = 16'h0001;

    localparam [15:0] SUB_R1_1_C1       = 16'h0001;
    localparam [15:0] SUB_1_R3_C3       = 16'h0001;

    localparam [15:0] SHLS_R3_C0        = 16'h0001;
    localparam [15:0] SHRS_C3_C2        = 16'h0001;
    localparam [15:0] SHRS_C3_C4        = 16'h0001;

    localparam [15:0] MOV_I_0          = 16'h0040;
    localparam [15:0] INC_I            = 16'h0100;
    localparam [15:0] REPEAT_5         = 16'h0800;
    localparam [15:0] JP_1             = 16'h4000;
    localparam [15:0] WAIT_IN          = 16'h8000;

    reg [15:0] tasks;
    always @(pc) begin
        case (pc)
            5'h0   : tasks = MOV_V0_1        ;
            5'h1   : tasks = WAIT_IN         ;

            5'h2   : tasks = CAL_SIN_W0      ;
            5'h3   : tasks = WAIT_CAL_DONE   |
                             MOV_R2_RES      ;
            5'h4   : tasks = CAL_COS_W0      ;
            5'h5   : tasks = WAIT_CAL_DONE   |
                             MOV_R3_RES      ;

            5'h6   : tasks = MUL_R2_INVQ_R1  ;
            5'h7   : tasks = NOP             ;
            5'h8   : tasks = NOP             ;

            5'h9   : tasks = CAL_INV_1_PLUS_R1;
            5'ha   : tasks = WAIT_CAL_DONE   |
                             MOV_R0_RES      ;

            5'hb   : tasks = SHLS_R3_C0      ;
            5'hc   : tasks = SUB_R1_1_C1     ;
            5'hd   : tasks = SUB_1_R3_C3     ;
            5'he   : tasks = SHRS_C3_C2      ;
            5'hf   : tasks = SHRS_C3_C4      ;

            5'h10  : tasks = MOV_I_0         |
            5'h11  : tasks = REPEAT_5        |
                             MUL_CI_R0_CI    |
                             INC_I           ;
            5'h12  : tasks = REPEAT_3        |
                             NOP             ;
            5'h13  : tasks = MOV_RES_AC      |
                             JP_1            ;
            default: tasks = JP_1            ;
        endcase
    end



    // PC
    reg [4:0] pc;
    always @(posedge reset or posedge clk) begin
        if (reset)
            pc <= 5'h0;
        else if (tasks & JP_1)
            pc <= 5'h1;
        else if ((tasks & WAIT_IN   && !do_calc ) ||      
                 (tasks & REPEAT_3  && repeat_st) ||
                 (tasks & REPEAT_10 && repeat_st))
            pc <= pc;
        else if (tasks & JP_J_N10_UP1 && j_reg != 5'ha)
            pc <= pc - 5'h1;
        else
            pc <= pc + 5'h1;
    end








//-----------------------------------------------------------------------------
// -------====== Connectionn between DSP and calculation modules ======-------
//-------------------------------------------------------------------------
    // Utilize same DSP from several modules
    
    // DSP owner selection
    localparam DSP_OWNER_LOCAL  = 0;
    localparam DSP_OWNER_TAYLOR = 1;

    // TODO
    wire  [1:0]  dsp_owner = (tasks & TODO) ? DSP_OWNER_IIR :
                             (tasks & TODO) ? DSP_OWNER_TAYLOR :
                             DSP_OWNER_LOCAL;


    // DSP signals interconnection
    wire [43:0] dsp_ins_flat_local;
    wire [43:0] dsp_ins_flat_taylor;
    wire [43:0] dsp_ins_flat_iir;

    assign dsp_ins_flat = 
        (owner == DSP_OWNER_LOCAL ) ?  dsp_ins_flat_local  :
        (owner == DSP_OWNER_TAYLOR) ?  dsp_ins_flat_taylor :
        44'h0;

    // DSP signals
    reg         [7:0]  opmode;
    reg  signed [17:0] a;
    reg  signed [17:0] b;
    wire signed [47:0] p;
    wire signed [35:0] m;

    // Gather local DSP signals 
    assign dsp_ins_flat_local[43:0] = { opmode, a, b };
    assign { m, p }        = dsp_ins_flat;





    // Taylor
    reg                taylor_do_calc;
    reg [2:0]          taylor_function_sel;
    reg  signed [17:0] taylor_x_in;
    wire               taylor_calc_done;
    wire signed [17:0] taylor_result;

    alu_taylor_calc alu_taylor_calc (
        .clk            (clk                 ),
        .reset          (reset               ),
        .do_calc        (taylor_do_calc      ),
        .function_sel   (taylor_function_sel ),
        .x_in           (taylor_x_in         ),
        .calc_done      (taylor_calc_done    ),
        .result         (taylor_result       ),
        .dsp_ins_flat   (taylor_dsp_ins_flat ),
        .dsp_outs_flat  (dsp_outs_flat       )
    );

endmodule

