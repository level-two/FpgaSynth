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
    localparam [15:0] NOP              = 16'h0000;

    localparam [15:0] CALC_SIN_W0      = 16'h0001;
    localparam [15:0] CALC_COS_W0      = 16'h0001;
    localparam [15:0] RECIP_1_PLUS_X   = 16'h0001;

    localparam [15:0] ADD_R_RES        = 16'h0001;
    localparam [15:0] SUB_R_RES        = 16'h0001;

    localparam [15:0] NEG_R            = 16'h0001;

    localparam [15:0] MUL_R_RES        = 16'h0001;


    localparam [15:0] MUL_X_FJ_VJ      = 16'h0001;
    localparam [15:0] MUL_X_FJ_VJ_AC0  = 16'h0002;
    localparam [15:0] MUL_VI_VJ_VJ     = 16'h0004;
    localparam [15:0] MUL_M_VJ_VJ      = 16'h0008;
    localparam [15:0] MUL_VI_CI_AC     = 16'h0010;
    localparam [15:0] MOV_V0_1         = 16'h0020;
    localparam [15:0] MOV_I_0          = 16'h0040;
    localparam [15:0] MOV_J_1          = 16'h0080;
    localparam [15:0] INC_I            = 16'h0100;
    localparam [15:0] INC_J            = 16'h0200;
    localparam [15:0] JP_J_N10_UP1     = 16'h0400;
    localparam [15:0] REPEAT_3         = 16'h0800;
    localparam [15:0] REPEAT_10        = 16'h1000;
    localparam [15:0] MOV_RES_AC       = 16'h2000;
    localparam [15:0] JP_1             = 16'h4000;
    localparam [15:0] WAIT_IN          = 16'h8000;

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
            4'h4   : tasks = (i_reg == 0) ?
                                 MUL_VI_VJ_VJ:
                                 MUL_M_VJ_VJ ;
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

