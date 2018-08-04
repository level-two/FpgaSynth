// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: sigma_delta_2order_dac.v
// Description: First order sigma-delta dac for audio output
// -----------------------------------------------------------------------------

`include "../globals.vh"

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

    // STORE SAMPLE_IN
    reg signed [17:0] sample_in_l_reg;
    reg signed [17:0] sample_in_r_reg;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            sample_in_l_reg <= 18'h00000;
            sample_in_r_reg <= 18'h00000;
        end
        else if (sample_in_rdy) begin
            // sample_in_reg <= 
            //    sample_in[17:16] == 2'b01 ? 18'h10000 :
            //    sample_in[17:16] == 2'b10 ? 18'h30000 : 
            //    sample_in;

            sample_in_l_reg <= sample_in_l;
            sample_in_r_reg <= sample_in_r;
        end
    end


    // TASKS
    localparam [23:0] NOP               = 24'h00000;
    localparam [23:0] WAIT_IN           = 24'h00001;
    localparam [23:0] JP_0              = 24'h00002;
    localparam [23:0] ADD_SL_I1L        = 24'h00004;
    localparam [23:0] ADD_SR_I1R        = 24'h00008;
    localparam [23:0] ADD_DL            = 24'h00010;
    localparam [23:0] ADD_DR            = 24'h00020;
    localparam [23:0] ADD_I2L           = 24'h00040;
    localparam [23:0] ADD_I2R           = 24'h00080;
    localparam [23:0] MOV_I1L_ACC       = 24'h00100;
    localparam [23:0] MOV_I1R_ACC       = 24'h00200;
    localparam [23:0] MOV_I2L_ACC       = 24'h00400;
    localparam [23:0] MOV_I2R_ACC       = 24'h00800;
    localparam [23:0] MOV_DL_ACCSGN     = 24'h01000;
    localparam [23:0] MOV_DR_ACCSGN     = 24'h02000;
    localparam [23:0] MOV_OUTL_ACCSGN   = 24'h04000;
    localparam [23:0] MOV_OUTR_ACCSGN   = 24'h08000;
    localparam [23:0] INC_DELTA_CNT     = 24'h10000;
              
    reg [23:0] tasks;
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
            4'h7   : tasks = MOV_DR_ACCSGN      |
                             MOV_I1R_ACC        |
                             MOV_OUTR_ACCSGN    |
                             INC_DELTA_CNT      |
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

    reg [3:0] delta_cnt;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            delta_cnt <= 4'h0;
        end
        else if (tasks & INC_DELTA_CNT) begin
            delta_cnt <= delta_cnt + 4'h1;
        end
    end

    reg signed [17:0] delta;
    always @(delta_cnt) begin
        case (delta_cnt)
            'h0    : begin delta <= 18'h18000; end
            'h1    : begin delta <= 18'h189CB; end
            'h2    : begin delta <= 18'h1921A; end
            'h3    : begin delta <= 18'h197A6; end
            'h4    : begin delta <= 18'h19999; end
            'h5    : begin delta <= 18'h197A6; end
            'h6    : begin delta <= 18'h1921A; end
            'h7    : begin delta <= 18'h189CB; end
            'h8    : begin delta <= 18'h18000; end
            'h9    : begin delta <= 18'h17634; end
            'ha    : begin delta <= 18'h16DE5; end
            'hb    : begin delta <= 18'h16859; end
            'hc    : begin delta <= 18'h16666; end
            'hd    : begin delta <= 18'h16859; end
            'he    : begin delta <= 18'h16DE5; end
            'hf    : begin delta <= 18'h17634; end
            default: begin delta <= 18'h00000; end
        endcase
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
            dab    = {30'h0, delta};
            c      = 48'h00000;
        end
        else if (tasks & ADD_DR) begin
            opmode = `DSP_XIN_DAB  |
                     `DSP_ZIN_POUT |
                     (delta_add_r ? `DSP_POSTADD_ADD : `DSP_POSTADD_SUB);
            dab    = {30'h0, delta};
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

