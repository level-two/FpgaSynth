// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: mudule_lpf_coefs_calc.v
// Description: Module for calculation of coefficients for LPF based on IIR
// -----------------------------------------------------------------------------

`include "globals.vh"

module mudule_lpf_coefs_calc (
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

//--------------------------------------------------------
// -------====== State Machine ======-------
//-----------------------------------------------------
    localparam ST_IDLE           = 0;
    localparam ST_X_MUL_COEF     = 1;
    localparam ST_INTM_MUL_INTM  = 2;
    localparam ST_INTM_MUL_DERIV = 3;
    localparam ST_WAIT_RESULT    = 4;
    localparam ST_DONE           = 5;

    reg [2:0] state;
    reg [2:0] next_state;

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            state <= ST_IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            ST_IDLE:           if (do_calc )  next_state = ST_X_MUL_COEF;
            ST_X_MUL_COEF:     if (last_idx)  next_state = ST_INTM_MUL_INTM;
            ST_INTM_MUL_INTM:                 next_state = ST_INTM_MUL_DERIV;
            ST_INTM_MUL_DERIV: if (!last_idx) next_state = ST_INTM_MUL_INTM;
                               else           next_state = ST_WAIT_RESULT;
            ST_WAIT_RESULT:    if (wait_done) next_state = ST_DONE;
            ST_DONE:                          next_state = ST_IDLE;
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
    reg  [1:0]  dsp_owner;
    always @(state) begin
        dsp_owner = DSP_OWNER_LOCAL;
        case (state)
            ST_IDLE:           begin end
            ST_IIR_CALC:       begin dsp_owner = DSP_OWNER_IIR; end
            ST_COS_CALC:       begin dsp_owner = DSP_OWNER_TAYLOR; end
            ST_WAIT_RESULT:    begin end
            ST_DONE:           begin end
        endcase
    end

    // DSP signals interconnection
    wire [43:0] dsp_ins_flat;
    wire [43:0] dsp_ins_flat_local;
    wire [43:0] dsp_ins_flat_taylor;
    wire [43:0] dsp_ins_flat_iir;
    wire [83:0] dsp_outs_flat;

    assign dsp_ins_flat = 
        (owner == DSP_OWNER_LOCAL ) ?  dsp_ins_flat_local  :
        (owner == DSP_OWNER_TAYLOR) ?  dsp_ins_flat_taylor :
        44'h0;

    // Gather local DSP signals 
    assign dsp_ins_flat_local[43:0] =
        { opmode_postadd_sub, opmode_preadd_sub,
          opmode_cryin      , opmode_use_preadd,
          opmode_z_in       , opmode_x_in      ,
          ain               , bin               };

    assign { m, p } = dsp_outs_flat;


//-----------------------------------------------------------
// -------====== Overflow error detection ======-------
//----------------------------------------------
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


//-------------------------------------------
// -------====== Result ======-------
//------------------------------
// TODO
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            calc_done <= 1'b0;
            result    <= 18'h00000;
        end
        else if (state == ST_DONE) begin
            calc_done <= 1'b1;
            result    <= p[33:16];
        end
        else begin
            calc_done <= 1'b0;
            result    <= 18'h00000;
        end
    end
endmodule

