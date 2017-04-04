// -----------------------------------------------------------------------------
// Copyright � 2017 Yauheni Lychkouski. All Rights Reserved
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


    localparam NOP            = 16'h0000;
    localparam MUL_C0_IN_AS   = 16'h0001;
    localparam MUL_CI_XYI_AC  = 16'h0002;
    localparam MOV_I_0        = 16'h0004;
    localparam INC_I          = 16'h0008;
    localparam MOV_RES_AC     = 16'h0010;
    localparam PUSH_X_IN      = 16'h0020;
    localparam PUSH_Y_AC      = 16'h0040;
    localparam REPEAT_4       = 16'h0080;
    localparam CAL_COEFS      = 16'h0100;
    localparam CAL_COEFS_WAIT = 16'h0200;
    localparam END            = 16'h8000;



    reg [15:0] tasks;

    always @(pc) begin
        case (pc)
            4'h0   : tasks = PUSH_X_IN     |
                             MOV_I_0       |
                             MUL_C0_IN_AS;

            4'h1   : tasks = REPEAT_4      |
                             MUL_CI_XYI_AC |
                             INC_I;

            4'h2   : tasks = NOP;
            4'h3   : tasks = NOP;
            4'h4   : tasks = MOV_RES_AC    |
                             PUSH_Y_AC;

            4'h2   : tasks = CAL_COEFS;
            4'h3   : tasks = CAL_COEFS_WAIT;
            default: tasks = END;
        endcase
    end





    reg [3:0] pc;




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
