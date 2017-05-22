// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: sigma_delta_2order_dac.v
// Description: First order sigma-delta dac for audio output
// -----------------------------------------------------------------------------

`include "globals.vh"

module sigma_delta_2order_dac
(
    input               clk,
    input               reset,
    input signed [17:0] sample_in,
    input               sample_in_rdy,
    input               sample_rate_trig,
    output reg          dout
);
 
    localparam signed [47:0] DELTA = 48'h10000;


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


    reg signed [17:0] cur_sample_reg;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            cur_sample_reg <= 18'h00000;
        end
        else if (sample_rate_trig) begin
            cur_sample_reg <= sample_in_reg;
        end
    end


    // TASKS
    localparam [7:0] NOP              = 8'h00;
    localparam [7:0] JP_0             = 8'h01;
    localparam [7:0] ADD_SMPL_INTEG1  = 8'h02;
    localparam [7:0] ADD_ACC_DELTA    = 8'h04;
    localparam [7:0] ADD_ACC_INTEG2   = 8'h08;
    localparam [7:0] MOV_INTEG1_ACC   = 8'h10;
    localparam [7:0] MOV_INTEG2_ACC   = 8'h20;
    localparam [7:0] MOV_DELTA_ACCSGN = 8'h40;
    localparam [7:0] MOV_OUT_ACCSGN   = 8'h80;
              
    reg [7:0] tasks;
    always @(pc) begin
        case (pc)
            4'h0   : tasks = ADD_SMPL_INTEG1    |
                             MOV_INTEG2_ACC     |
                             MOV_DELTA_ACCSGN   |
                             MOV_OUT_ACCSGN     ;
            4'h1   : tasks = ADD_ACC_DELTA      ;
            4'h2   : tasks = ADD_ACC_INTEG2     |
                             MOV_INTEG1_ACC     ;
            4'h3   : tasks = ADD_ACC_DELTA      |
                             JP_0               ;
            default: tasks = JP_0               ;
        endcase
    end


    // PC
    reg [1:0] pc;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            pc <= 2'h0;
        end
        else if (tasks & JP_0) begin
            pc <= 2'h0;
        end
        else begin
            pc <= pc + 2'h1;
        end
    end


    // ADDER TASKS
    always @(*) begin
        opmode = `DSP_NOP;
        dab    = 48'h00000;
        c      = 48'h00000;
        if (tasks & ADD_SMPL_INTEG1) begin
            opmode = `DSP_XIN_DAB  | 
                     `DSP_ZIN_CIN  |
                     `DSP_POSTADD_ADD;
            dab    = integ1;
            c      = { {30{cur_sample_reg[17]}}, cur_sample_reg[17:0] };
        end
        else if (tasks & ADD_ACC_DELTA) begin
            opmode = `DSP_XIN_DAB  |
                     `DSP_ZIN_POUT |
                     (delta_add ? `DSP_POSTADD_ADD : `DSP_POSTADD_SUB);
            dab    = DELTA;
            c      = 48'h00000;
        end
        else if (tasks & ADD_ACC_INTEG2) begin
            opmode = `DSP_XIN_DAB  |
                     `DSP_ZIN_POUT |
                     `DSP_POSTADD_ADD;
            dab    = integ2;
            c      = 48'h00000;
        end
    end


    reg signed [47:0] integ1;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            integ1 <= 48'h0;
        end
        else if (tasks & MOV_INTEG1_ACC) begin
            integ1 <= p;
        end
    end


    reg signed [47:0] integ2;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            integ2 <= 48'h0;
        end
        else if (tasks & MOV_INTEG2_ACC) begin
            integ2 <= p;
        end
    end


    reg delta_add;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            delta_add <= 1'h0;
        end
        else if (tasks & MOV_DELTA_ACCSGN) begin
            delta_add <= p[47];
        end
    end


    always @(posedge reset or posedge clk) begin
        if (reset) begin
            dout <= 1'h0;
        end
        else if (tasks & MOV_OUT_ACCSGN) begin
            dout <= ~p[47];
        end
    end


    reg         [7:0]  opmode;
    reg  signed [47:0] dab;
    reg  signed [47:0] c;
    wire signed [47:0] p;

    dsp48a1_adder dsp48a1_adder
    (
        .clk        (clk        ),
        .reset      (reset      ),
        .opmode     (opmode     ),
        .dabin      (dab        ),
        .cin        (c          ),
        .pout       (p          )
    );

endmodule

