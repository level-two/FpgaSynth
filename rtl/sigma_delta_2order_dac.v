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
    input signed [17:0] sample_in_l,
    input signed [17:0] sample_in_r,
    input               sample_in_rdy,
    output reg          dout_l,
    output reg          dout_r
);
 
    localparam signed [47:0] DELTA = 48'h20000;


    // STORE SAMPLE_IN
    reg signed [17:0] sample_in_l_reg;
    reg signed [17:0] sample_in_r_reg;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            sample_in_l_reg <= 18'h00000;
            sample_in_r_reg <= 18'h00000;
        end
        else if (sample_in_rdy) begin
            sample_in_l_reg <= 
               sample_in_l[17:16] == 2'b01 ? 18'h10000 :
               sample_in_l[17:16] == 2'b10 ? 18'h30000 : 
               sample_in_l;
            sample_in_r_reg <= 
               sample_in_r[17:16] == 2'b01 ? 18'h10000 :
               sample_in_r[17:16] == 2'b10 ? 18'h30000 : 
               sample_in_r;

            //sample_in_l_reg <= sample_in_l;
            //sample_in_r_reg <= sample_in_r;
        end
    end


    // TASKS
    localparam [15:0] NOP               = 16'h0000;
    localparam [15:0] WAIT_IN           = 16'h0001;
    localparam [15:0] JP_0              = 16'h0002;
    localparam [15:0] ADD_SL_I1L        = 16'h0004;
    localparam [15:0] ADD_SR_I1R        = 16'h0008;
    localparam [15:0] ADD_DL            = 16'h0010;
    localparam [15:0] ADD_DR            = 16'h0020;
    localparam [15:0] ADD_I2L           = 16'h0040;
    localparam [15:0] ADD_I2R           = 16'h0080;
    localparam [15:0] MOV_I1L_ACC       = 16'h0100;
    localparam [15:0] MOV_I1R_ACC       = 16'h0200;
    localparam [15:0] MOV_I2L_ACC       = 16'h0400;
    localparam [15:0] MOV_I2R_ACC       = 16'h0800;
    localparam [15:0] MOV_DL_ACCSGN     = 16'h1000;
    localparam [15:0] MOV_DR_ACCSGN     = 16'h2000;
    localparam [15:0] MOV_OUTL_ACCSGN   = 16'h4000;
    localparam [15:0] MOV_OUTR_ACCSGN   = 16'h8000;
              
    reg [15:0] tasks;
    always @(pc) begin
        case (pc)
            4'h0   : tasks = WAIT_IN            ;
            // Left sample calc
            4'h1   : tasks = ADD_SL_I1L         ;
            4'h2   : tasks = ADD_DL             ;
            4'h3   : tasks = MOV_I1L_ACC        |
                             ADD_I2L            ;
            4'h4   : tasks = ADD_DL             ;
            4'h5   : tasks = MOV_DL_ACCSGN      |
                             MOV_I2L_ACC        |
                             MOV_OUTL_ACCSGN    |
            // Right sample calc
                             ADD_SR_I1R         ;
            4'h6   : tasks = ADD_DR             ;
            4'h7   : tasks = MOV_I1R_ACC        |
                             ADD_I2R            ;
            4'h8   : tasks = ADD_DR             ;
            4'h9   : tasks = MOV_DR_ACCSGN      |
                             MOV_I2R_ACC        |
                             MOV_OUTR_ACCSGN    |
                             JP_0               ;
            default: tasks = JP_0               ;
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
        else if (tasks & WAIT_IN && !sample_in_rdy) begin
            pc <= pc;
        end
        else begin
            pc <= pc + 4'h1;
        end
    end


    // ADDER TASKS
    always @(*) begin
        opmode = `DSP_NOP;
        dab    = 48'h00000;
        c      = 48'h00000;
        if (tasks & ADD_SL_I1L) begin
            opmode = `DSP_XIN_DAB  | 
                     `DSP_ZIN_CIN  |
                     `DSP_POSTADD_ADD;
            dab    = integ1_l;
            c      = { {30{sample_in_l_reg[17]}}, sample_in_l_reg[17:0] };
        end
        else if (tasks & ADD_SR_I1R) begin
            opmode = `DSP_XIN_DAB  | 
                     `DSP_ZIN_CIN  |
                     `DSP_POSTADD_ADD;
            dab    = integ1_r;
            c      = { {30{sample_in_r_reg[17]}}, sample_in_r_reg[17:0] };
        end
        else if (tasks & ADD_DL) begin
            opmode = `DSP_XIN_DAB  |
                     `DSP_ZIN_POUT |
                     (delta_add_l ? `DSP_POSTADD_ADD : `DSP_POSTADD_SUB);
            dab    = DELTA;
            c      = 48'h00000;
        end
        else if (tasks & ADD_DR) begin
            opmode = `DSP_XIN_DAB  |
                     `DSP_ZIN_POUT |
                     (delta_add_r ? `DSP_POSTADD_ADD : `DSP_POSTADD_SUB);
            dab    = DELTA;
            c      = 48'h00000;
        end
        else if (tasks & ADD_I2L) begin
            opmode = `DSP_XIN_DAB  |
                     `DSP_ZIN_POUT |
                     `DSP_POSTADD_ADD;
            dab    = integ2_l;
            c      = 48'h00000;
        end
        else if (tasks & ADD_I2R) begin
            opmode = `DSP_XIN_DAB  |
                     `DSP_ZIN_POUT |
                     `DSP_POSTADD_ADD;
            dab    = integ2_r;
            c      = 48'h00000;
        end
    end


    reg signed [47:0] integ1_l;
    reg signed [47:0] integ1_r;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            integ1_l <= 48'h0;
            integ1_r <= 48'h0;
        end
        else if (tasks & MOV_I1L_ACC) begin
            integ1_l <= p;
        end
        else if (tasks & MOV_I1R_ACC) begin
            integ1_r <= p;
        end
    end


    reg signed [47:0] integ2_l;
    reg signed [47:0] integ2_r;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            integ2_l <= 48'h0;
            integ2_r <= 48'h0;
        end
        else if (tasks & MOV_I2L_ACC) begin
            integ2_l <= p;
        end
        else if (tasks & MOV_I2R_ACC) begin
            integ2_r <= p;
        end
    end


    reg delta_add_l;
    reg delta_add_r;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            delta_add_l <= 1'h0;
            delta_add_r <= 1'h0;
        end
        else if (tasks & MOV_DL_ACCSGN) begin
            delta_add_l <= p[47];
        end
        else if (tasks & MOV_DR_ACCSGN) begin
            delta_add_r <= p[47];
        end
    end


    always @(posedge reset or posedge clk) begin
        if (reset) begin
            dout_l <= 1'h0;
            dout_r <= 1'h0;
        end
        else if (tasks & MOV_OUTL_ACCSGN) begin
            dout_l <= ~p[47];
        end
        else if (tasks & MOV_OUTR_ACCSGN) begin
            dout_r <= ~p[47];
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

