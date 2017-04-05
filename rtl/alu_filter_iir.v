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

    // STORE SAMPLE_IN
    reg signed [17:0] sample_in_reg;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            sample_in_reg <= 18'h00000;
        end
        else if (sample_in_rdy) begin
            sample_in_reg <= sample_in;
        end
    end


    // TASKS
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
    localparam JP_0           = 16'h0400;
    localparam WAIT_IN        = 16'h0800;


    reg [15:0] tasks;
    always @(pc) begin
        case (pc)
            4'h0   : tasks = WAIT_IN;
            4'h1   : tasks = PUSH_X_IN     |
                             MOV_I_0       |
                             MUL_C0_IN_AS;

            4'h2   : tasks = REPEAT_4      |
                             MUL_CI_XYI_AC |
                             INC_I;

            4'h3   : tasks = NOP;
            4'h4   : tasks = NOP;
            4'h5   : tasks = MOV_RES_AC    |
                             PUSH_Y_AC;

            4'h6   : tasks = CAL_COEFS;
            4'h7   : tasks = CAL_COEFS_WAIT;
            default: tasks = JP_0;
        endcase
    end


    // PC
    reg [3:0] pc;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            pc <= 4'h0;
        end
        else if (tasks & JP_0) begin
            pc <= 4'h0;
        end
        else if((tasks & WAIT_IN  && !sample_in_rdy) ||      
                (tasks & REPEAT_4 && repeat_st     ))
        begin
            pc <= pc;
        end
        else begin
            pc <= pc + 4'h1;
        end
    end


    // REPEAT
    reg  [3:0] repeat_cnt;
    wire [3:0] repeat_cnt_max = (tasks & REPEAT_4) ? 4'h3 : 4'h0;
    wire       repeat_st      = (repeat_cnt != repeat_cnt_max);

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            repeat_cnt <= 4'h0;
        end
        else if (repeat_cnt == repeat_cnt_max) begin
            repeat_cnt <= 4'h0;
        end
        else begin
            repeat_cnt <= repeat_cnt + 4'h1;
        end
    end


    // INDEX REGISTER I
    reg  [3:0] i_reg;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            i_reg <= 4'h0;
        end
        else if (tasks & MOV_I_0) begin
            i_reg <= 4'h0;
        end
        else if (tasks & INC_I) begin
            i_reg <= i_reg + 4'h1;
        end
    end


    // XY DELAY LINE
    reg  signed [17:0] xy_dly_line[0:4];
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            xy_dly_line[0] <= 18'h00000;
            xy_dly_line[1] <= 18'h00000;
            xy_dly_line[2] <= 18'h00000;
            xy_dly_line[3] <= 18'h00000;
            xy_dly_line[4] <= 18'h00000;
        end
        else if (tasks & PUSH_X_IN) begin
            xy_dly_line[0] <= sample_in_reg;
            xy_dly_line[1] <= xy_dly_line[0];
            xy_dly_line[2] <= xy_dly_line[1];
        end
        else if (tasks & PUSH_Y_AC) begin
            xy_dly_line[3] <= p[33:16];
            xy_dly_line[4] <= xy_dly_line[3];
        end
    end


    // MOVE AC VALUE TO RESULTS
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            sample_out_rdy <= 1'b0;
            sample_out     <= 18'h00000;
        end
        else if (tasks & MOV_RES_AC) begin
            sample_out_rdy <= 1'b1;
            sample_out     <= p[33:16];
        end
        else begin
            sample_out_rdy <= 1'b0;
            sample_out     <= 18'h00000;
        end
    end




    wire signed [17:0] xyi = xy_dly_line[i_reg];

    localparam MUL_C0_IN_AS   = 16'h0001;
    localparam MUL_CI_XYI_AC  = 16'h0002;

    // MUL TASKS
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            sample_out_rdy <= 1'b0;
            sample_out     <= 18'h00000;
        end
        else if (tasks & MOV_RES_AC) begin
            sample_out_rdy <= 1'b1;
            sample_out     <= p[33:16];
        end
        else begin
            sample_out_rdy <= 1'b0;
            sample_out     <= 18'h00000;
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




endmodule
