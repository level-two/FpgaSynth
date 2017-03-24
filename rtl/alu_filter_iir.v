// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: alu_filter_iir.v
// Description: IIR implementation based on Xilinx DSP48A1
// -----------------------------------------------------------------------------

`include "globals.vh"

module alu_filter_iir (
    input                    clk,
    input                    reset,
    input  [5*18-1:0]        coefs_flat,
    input  signed [17:0]     sample_in,
    input                    sample_in_rdy,
    output signed [17:0]     sample_out,
    output                   sample_out_rdy,

    input  [43:0]            dsp_ins_flat,
    output [83:0]            dsp_outs_flat
);


//--------------------------------------------------------
// -------====== State Machine ======-------
//-----------------------------------------------------
    localparam ST_IDLE         = 0;
    localparam ST_CALC         = 1;
    localparam ST_WAIT_RESULT  = 2;
    localparam ST_DONE         = 3;

    reg [1:0] state;
    reg [1:0] next_state;

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
            ST_IDLE:
                if (sample_in_rdy) begin
                    next_state = ST_CALC;
                end
            ST_CALC:
                if (coef_sel_last) begin
                    next_state = ST_WAIT_RESULT;
                end
            ST_WAIT_RESULT:
                if (calc_will_be_done) begin
                    next_state = ST_DONE;
                end
            ST_DONE:
                next_state = ST_IDLE;
        endcase
    end


//---------------------------------------------
// -------====== DSP signals ======-------
//-----------------------------------------
    reg [1:0]   opmode_x_in;
    reg [1:0]   opmode_z_in;
    reg         opmode_use_preadd;
    reg         opmode_cryin;
    reg         opmode_preadd_sub;
    reg         opmode_postadd_sub;
    wire signed [17:0] a;
    wire signed [17:0] b;
    wire signed [47:0] p;
    wire signed [35:0] m_nc;

    // Gather local DSP signals 
    assign dsp_ins_flat[43:0] =
        { opmode_postadd_sub, opmode_preadd_sub, opmode_cryin,
          opmode_use_preadd , opmode_z_in      , opmode_x_in ,
          a                 , b };

    assign { m_nc, p } = dsp_outs_flat;


//------------------------------------
// -------====== COEFS ======-------
//--------------------------------
    wire signed [17:0] coefs[0:4];
    genvar i;
    generate
        for (i = 0; i < 5; i=i+1) begin : COEFS_BLK
            assign coefs[i] = coefs_flat[18*i +: 18];
        end
    endgenerate


    reg [2:0] coef_sel;
    wire      coef_sel_last  = (coef_sel == 3'h4);
    
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            coef_sel <= 0;
        end
        else if (state == ST_CALC && !coef_sel_last) begin
            coef_sel <= coef_sel + 1;
        end
        else begin
            coef_sel <= 0;
        end
    end


//---------------------------------------------
// -------====== Delay line ======-------
//-----------------------------------------
    reg  signed [17:0] xy_dly_line[0:4];
    wire signed [17:0] xy = xy_dly_line[coef_sel];

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            xy_dly_line[0] <= 18'h00000;
            xy_dly_line[1] <= 18'h00000;
            xy_dly_line[2] <= 18'h00000;
            xy_dly_line[3] <= 18'h00000;
            xy_dly_line[4] <= 18'h00000;
        end
        else if (state == ST_IDLE && sample_in_rdy) begin
            xy_dly_line[0] <= sample_in;
            xy_dly_line[1] <= xy_dly_line[0];
            xy_dly_line[2] <= xy_dly_line[1];
        end
        else if (state == ST_DONE) begin
            xy_dly_line[3] <= p[33:16];
            xy_dly_line[4] <= xy_dly_line[3];
        end
    end


//----------------------------------
// -------====== A,B ======-------
//------------------------------
    assign a = xy;
    assign b = coefs[coef_sel];


//-------------------------------------------------------------
// -------====== ALU Operation mode controll ======-------
//---------------------------------------------------------
    always @(state) begin
        opmode_x_in        = `DSP_X_IN_ZERO;
        opmode_z_in        = `DSP_Z_IN_ZERO;
        opmode_use_preadd  = 1'b0;
        opmode_cryin       = 1'b0;
        opmode_preadd_sub  = 1'b0;
        opmode_postadd_sub = 1'b0;

        case (state)
            ST_IDLE:           begin end
            ST_CALC: begin
                opmode_x_in = `DSP_X_IN_MULT;
                opmode_z_in = `DSP_Z_IN_POUT;
            end
            ST_WAIT_RESULT:  begin end
            ST_DONE:           begin end
        endcase
    end


//--------------------------------------------------------
// -------====== Wait Result ======-------
//----------------------------------------------------
    reg [1:0] wait_clac_cnt;
    wire      calc_will_be_done = (wait_clac_cnt == 2'h1);

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            wait_clac_cnt <= 0;
        end
        else if (state == ST_WAIT_RESULT) begin
            wait_clac_cnt <= wait_clac_cnt + 1;
        end
        else begin
            wait_clac_cnt <= 0;
        end
    end


//--------------------------------------------------------
// -------====== Output ======-------
//----------------------------------------------------
    assign sample_out     = (state == ST_DONE) ? p[33:16] : 18'h00000;
    assign sample_out_rdy = (state == ST_DONE) ? 1 : 0;

endmodule
