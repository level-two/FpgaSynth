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
//   interm_val = 1;
//   sum = deriv(1);
//   x = pi/2;
//   for n = 1:10
//       a1 = interm_val * fac_nums(n);
//       interm_val = a1 * x;
//       sum = sum + interm_val*deriv(n+1);
//   end
// -----------------------------------------------------------------------------

`include "globals.vh"

module alu_taylor_calc (
    input                clk,
    input                reset,

    input                do_calc,
    input [2:0]          function_sel,
    input signed [17:0]  x_in,

    output               calc_done,
    output signed [17:0] result,
    output reg           err_overflow,

    input  [43:0]        dsp_ins_flat,
    output [83:0]        dsp_outs_flat
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


//---------------------------------------------------------------------------
// -------====== Derivatives values for the Taylor series ======-------
//----------------------------------------------------------------
    reg [3:0] idx;
    wire last_idx;
    reg [2:0] function_sel_st;
    wire signed [17:0] deriv_coef;

    alu_taylor_coefs alu_taylor_coefs (
        .function_sel(function_sel_st),
        .idx         (idx            ),
        .last_idx    (last_idx       ),
        .deriv_coef  (deriv_coef     )
    );


//----------------------------------------------------------
// -------====== DSP instance and signals ======-------
//-------------------------------------------------
    reg [1:0]   opmode_x_in;
    reg [1:0]   opmode_z_in;
    reg         opmode_use_preadd;
    reg         opmode_cryin;
    reg         opmode_preadd_sub;
    reg         opmode_postadd_sub;
    reg  signed [17:0] a;
    reg  signed [17:0] b;
    wire signed [35:0] m;
    wire signed [47:0] p;

    // Gather local DSP signals 
    assign dsp_ins_flat[43:0] =
        { opmode_postadd_sub, opmode_preadd_sub, opmode_cryin,
          opmode_use_preadd , opmode_z_in      , opmode_x_in ,
          a                 , b };

    assign { m, p } = dsp_outs_flat;


//-------------------------------------------------------------
// -------====== DSP Operation mode controll ======-------
//---------------------------------------------------------
    always @(*) begin
        store_idx          = 0;
        store_m_trig       = 1'b0;
        a                  = 18'h00000;
        b                  = 18'h00000;
        opmode_x_in        = `DSP_X_IN_ZERO;
        opmode_z_in        = `DSP_Z_IN_ZERO;
        opmode_use_preadd  = 1'b0;
        opmode_cryin       = 1'b0;
        opmode_preadd_sub  = 1'b0;
        opmode_postadd_sub = 1'b0;

        case (state)
            ST_IDLE:           begin end
            ST_X_MUL_COEF:     begin
                store_m_trig = 1'b1;
                store_idx    = idx;
                a            = (idx != 0) ? x : 18'h10000;
                b            = frac_coef;
            end
            ST_INTM_MUL_INTM:  begin
                store_idx    = idx+1;
                store_m_trig = last_idx   ? 1'b0 : 1'b1;
                a            = (idx == 0) ? interm_val[0] : m[33:16];
                b            = last_idx   ? 18'h00000 : interm_val[idx+1];
                opmode_x_in  = `DSP_X_IN_ZERO; // Skip result from multiplier
                opmode_z_in  = `DSP_Z_IN_POUT;
            end
            ST_INTM_MUL_DERIV: begin
                a            = interm_val[idx];
                b            = deriv_coef;
                opmode_x_in  = `DSP_X_IN_MULT; // Accept result from multiplier
                opmode_z_in  = `DSP_Z_IN_POUT;
            end
            ST_WAIT_RESULT:    begin end
            ST_DONE:           begin end
        endcase
    end


//------------------------------------------
// -------====== X value ======-------
//-------------------------------
    reg signed [17:0] x;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            x <= 18'h00000;
        end
        else if (state == ST_IDLE && do_calc == 1'b1) begin
            x <= x_in; // store input value for calculation
            function_sel_st <= function_sel;
        end
    end


//---------------------------------------------------------------------
// -------====== Numbers for factorial calculation ======-------
//--------------------------------------------------------
    reg signed [17:0] frac_coef;
    always @(idx) begin
        case (idx)
            4'h0   : begin frac_coef <= 18'h10000; end // 1
            4'h1   : begin frac_coef <= 18'h10000; end // 1
            4'h2   : begin frac_coef <= 18'h08000; end // 1/2
            4'h3   : begin frac_coef <= 18'h05555; end // 1/3
            4'h4   : begin frac_coef <= 18'h04000; end // 1/4
            4'h5   : begin frac_coef <= 18'h03333; end // 1/5
            4'h6   : begin frac_coef <= 18'h02aab; end // 1/6
            4'h7   : begin frac_coef <= 18'h02492; end // 1/7
            4'h8   : begin frac_coef <= 18'h02000; end // 1/8
            4'h9   : begin frac_coef <= 18'h01c72; end // 1/9
            4'ha   : begin frac_coef <= 18'h0199a; end // 1/10
            default: begin frac_coef <= 18'h00000; end
        endcase
    end


//----------------------------------------------------------------------
// -------====== Obtain intermediate value from DSP ======-------
//-------------------------------------------------------
    reg       store_m_trig;
    reg [3:0] store_idx;

    reg       store_m_trig_dly[0:1];
    reg [3:0] store_idx_dly[0:1];
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            store_m_trig_dly[0] <= 1'b0;
            store_m_trig_dly[1] <= 1'b0;
            store_idx_dly[0]    <= 4'h0;
            store_idx_dly[1]    <= 4'h0;
        end 
        else begin
            store_m_trig_dly[0] <= store_m_trig;
            store_m_trig_dly[1] <= store_m_trig_dly[0];
            store_idx_dly[0]    <= store_idx;
            store_idx_dly[1]    <= store_idx_dly[0];
        end
    end

    
    reg signed [17:0] interm_val[0:10];
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            // do nothing
        end 
        else if (store_m_trig_dly[1] == 1'b1) begin
            interm_val[store_idx_dly[1]] <= m[33:16];
        end
    end


//-----------------------------------------------
// -------====== idx counter ======-------
//-----------------------------------
    always @(posedge reset or posedge clk) begin
        if (reset)
            idx <= 4'h0;
        else if (state == ST_INTM_MUL_INTM)
            idx <= idx;
        else if (last_idx)
            idx <= 4'h0;
        else if (state == ST_X_MUL_COEF || state == ST_INTM_MUL_DERIV)
            idx <= idx + 1;
        else
            idx <= 4'h0;
    end


//--------------------------------------------------------
// -------====== Wait Result ======-------
//----------------------------------------------------
    reg [1:0] wait_clac_cnt;
    wire      wait_done = (wait_clac_cnt == 2'h1);

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            wait_clac_cnt <= 2'h0;
        end
        else if (state == ST_WAIT_RESULT) begin
            wait_clac_cnt <= wait_clac_cnt + 1;
        end
        else begin
            wait_clac_cnt <= 2'h0;
        end
    end


//-----------------------------------------------------------
// -------====== Overflow error detection ======-------
//----------------------------------------------
    // When overflow occured, ie multiplication result is >= 2.0 or
    // <= -2.0, higher bits will not be equal
    wire err_overflow_m = m[35]^m[34];
    wire err_overflow_p = &p[48:34] != |p[48:34]; // 00000 or 00010; 11111 or 11101

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            err_overflow <= 1'b0;
        end
        else if (state == ST_IDLE) begin
            err_overflow <= 1'b0;
        end
        else begin
            err_overflow <= err_overflow | err_overflow_m | err_overflow_p;
        end
    end

//-------------------------------------------
// -------====== Result ======-------
//------------------------------
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

