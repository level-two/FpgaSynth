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
    output reg signed [17:0] sample_out,
    output reg               sample_out_rdy,

    input  [83:0]            dsp_outs_flat,
    output [43:0]            dsp_ins_flat
);


    // opcodes
    localparam NOP = 4'h0;
    localparam MUL = 4'h1;
    localparam ADD = 4'h2;
    localparam SUB = 4'h3;
    //localparam MOV = 4h'3;
    localparam MOV = {4'h3, NOA, 4'h0};
    localparam END = 4'hF;

    // arguments
    localparam NOA = 3'h0; // no argument
    localparam REG = 3'h1; // register
    localparam CON = 3'h2; // constant
    localparam ACC = 3'h3; // accumulator

    localparam R0 = {REG, 4'h0};
    localparam R1 = {REG, 4'h1};
    localparam R2 = {REG, 4'h2};
    localparam R3 = {REG, 4'h3};
    localparam R4 = {REG, 4'h4};

    localparam C0 = {CON, 4'h0};
    localparam C1 = {CON, 4'h1};
    localparam C2 = {CON, 4'h2};
    localparam C3 = {CON, 4'h3};
    localparam C4 = {CON, 4'h4};

    localparam AC = {ACC, 4'h0}; // usual accumulator
    localparam AS = {ACC, 4'h1}; // summing accumulator


    reg [3:0] pc;
    reg [24:0] instr;
    always @(pc) begin
        case (pc)
            4'h0   : begin instr <= { MUL, R0, C0, AC }; end
            4'h1   : begin instr <= { MUL, R1, C1, AS }; end
            4'h2   : begin instr <= { MUL, R2, C2, AS }; end
            4'h3   : begin instr <= { MUL, R3, C3, AS }; end
            4'h4   : begin instr <= { MUL, R4, C4, AS }; end
            4'h5   : begin instr <= { MOV, R0, R1     }; end
            4'h6   : begin instr <= { MOV, R1, R2     }; end
            4'h7   : begin instr <= { MOV, R2, R3     }; end
            4'h8   : begin instr <= { MOV, R3, R4     }; end
            4'h9   : begin instr <= { MOV, AC, R0     }; end
            default: begin instr <= { END             }; end
        endcase
    end


















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

//-------------------------------------------
// -------====== Output ======-------
//------------------------------
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            sample_out_rdy <= 1'b0;
            sample_out     <= 18'h00000;
        end
        else if (state == ST_DONE) begin
            sample_out_rdy <= 1'b1;
            sample_out     <= p[33:16];
        end
        else begin
            sample_out_rdy <= 1'b0;
            sample_out     <= 18'h00000;
        end
    end
endmodule
