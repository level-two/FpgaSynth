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
    input                        clk        ,
    input                        reset      ,
    input             [5*18-1:0] coefs_flat ,
    input      signed [17:0]     smp_in_l   ,
    input      signed [17:0]     smp_in_r   ,
    input                        smp_in_rdy ,
    output reg signed [17:0]     smp_out_l  ,
    output reg signed [17:0]     smp_out_r  ,
    output reg                   smp_out_rdy,

    // DSP
    output            [ 7:0]     dsp_op     ,
    output     signed [17:0]     dsp_al     ,
    output     signed [17:0]     dsp_bl     ,
    output     signed [47:0]     dsp_cl     ,
    input      signed [47:0]     dsp_pl     ,
    output     signed [17:0]     dsp_ar     ,
    output     signed [17:0]     dsp_br     ,
    output     signed [47:0]     dsp_cr     ,
    input      signed [47:0]     dsp_pr     ,
    output                       dsp_req    ,
    input                        dsp_gnt
);


    // STORE SAMPLE_IN
    reg signed [17:0] smp_in_l_reg;
    reg signed [17:0] smp_in_r_reg;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            smp_in_l_reg <= 18'h00000;
            smp_in_r_reg <= 18'h00000;
        end
        else if (smp_in_rdy) begin
            smp_in_l_reg <= smp_in_l;
            smp_in_r_reg <= smp_in_r;
        end
    end


    // TASKS
    localparam [15:0] NOP            = 16'h0000;
    localparam [15:0] MUL_CI_IN_AS   = 16'h0001;
    localparam [15:0] MUL_CI_XYI_AC  = 16'h0002;
    localparam [15:0] MOV_I_0        = 16'h0004;
    localparam [15:0] INC_I          = 16'h0008;
    localparam [15:0] MOV_RES_AC     = 16'h0010;
    localparam [15:0] PUSH_X_IN      = 16'h0020;
    localparam [15:0] PUSH_Y_AC      = 16'h0040;
    localparam [15:0] REPEAT_3       = 16'h0080;
    localparam [15:0] CAL_COEFS      = 16'h0100;
    localparam [15:0] CAL_COEFS_WAIT = 16'h0200;
    localparam [15:0] JP_0           = 16'h0400;
    localparam [15:0] WAIT_IN        = 16'h0800;
              
    reg [15:0] tasks;
    always @(pc) begin
        case (pc)
            4'h0   : tasks = WAIT_IN       ;
            4'h1   : tasks = PUSH_X_IN     |
                             MUL_CI_IN_AS  |
                             INC_I         ;
            4'h2   : tasks = REPEAT_3      |
                             MUL_CI_XYI_AC |
                             INC_I         ;
            4'h3   : tasks = MUL_CI_XYI_AC |
                             MOV_I_0       ;
            4'h4   : tasks = REPEAT_3      |
                             NOP           ;
            4'h5   : tasks = MOV_RES_AC    |
                             PUSH_Y_AC     |
                             JP_0          ;
            default: tasks = JP_0          ;
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
        else if ((tasks & WAIT_IN  && !smp_in_rdy) ||      
                 (tasks & REPEAT_3 && repeat_st     ))
        begin
            pc <= pc;
        end
        else begin
            pc <= pc + 4'h1;
        end
    end


    // REPEAT
    reg  [3:0] repeat_cnt;
    wire [3:0] repeat_cnt_max = (tasks & REPEAT_3) ? 4'h2 : 4'h0;
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
    reg signed [17:0] xy_l_dly_line[0:4];
    reg signed [17:0] xy_r_dly_line[0:4];
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            xy_l_dly_line[0] <= 18'h00000;
            xy_l_dly_line[1] <= 18'h00000;
            xy_l_dly_line[2] <= 18'h00000;
            xy_l_dly_line[3] <= 18'h00000;
            xy_l_dly_line[4] <= 18'h00000;

            xy_r_dly_line[0] <= 18'h00000;
            xy_r_dly_line[1] <= 18'h00000;
            xy_r_dly_line[2] <= 18'h00000;
            xy_r_dly_line[3] <= 18'h00000;
            xy_r_dly_line[4] <= 18'h00000;
        end
        else if (tasks & PUSH_X_IN) begin
            xy_l_dly_line[0] <= smp_in_l_reg;
            xy_l_dly_line[1] <= xy_l_dly_line[0];
            xy_l_dly_line[2] <= xy_l_dly_line[1];

            xy_r_dly_line[0] <= smp_in_r_reg;
            xy_r_dly_line[1] <= xy_r_dly_line[0];
            xy_r_dly_line[2] <= xy_r_dly_line[1];
        end
        else if (tasks & PUSH_Y_AC) begin
            xy_l_dly_line[3] <= dsp_pl[36:34] == 3'h0 ? dsp_pl[33:16] :
                                dsp_pl[36:34] == 3'h7 ? dsp_pl[33:16] :
                                xy_l_dly_line[3];
            xy_l_dly_line[4] <= xy_l_dly_line[3];

            xy_r_dly_line[3] <= dsp_pr[36:34] == 3'h0 ? dsp_pr[33:16] :
                                dsp_pr[36:34] == 3'h7 ? dsp_pr[33:16] :
                                xy_r_dly_line[3];
            xy_r_dly_line[4] <= xy_r_dly_line[3];
        end
    end

    // Coefficients
    wire signed [17:0] coefs[0:4];
    //assign coefs[0] = 18'h0009b; // b0
    //assign coefs[1] = 18'h00137; // b1
    //assign coefs[2] = 18'h0009b; // b2
    //assign coefs[3] = 18'h1e538; // a1
    //assign coefs[4] = 18'h31858; // a2

    genvar i;
    generate
        for (i = 0; i < 5; i=i+1) begin : COEFS_BLK
            assign coefs[i] = coefs_flat[18*i +: 18];
        end
    endgenerate


    // MUL TASKS
    wire signed [17:0] ci    = coefs[i_reg];
    wire signed [17:0] xyi_l = xy_l_dly_line[i_reg];
    wire signed [17:0] xyi_r = xy_r_dly_line[i_reg];
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            dsp_op <= `DSP_NOP;
            dsp_al <= 18'h00000;
            dsp_bl <= 18'h00000;
            dsp_ar <= 18'h00000;
            dsp_br <= 18'h00000;
        end
        else if (tasks & MUL_CI_IN_AS) begin
            dsp_op <= `DSP_XIN_MULT | `DSP_ZIN_ZERO;
            dsp_al <= ci;
            dsp_bl <= smp_in_l_reg;
            dsp_ar <= ci;
            dsp_br <= smp_in_r_reg;
        end
        else if (tasks & MUL_CI_XYI_AC) begin
            dsp_op <= `DSP_XIN_MULT | `DSP_ZIN_POUT;
            dsp_al <= ci;
            dsp_bl <= xyi_l;
            dsp_ar <= ci;
            dsp_br <= xyi_r;
        end
        else begin
            dsp_op <= `DSP_NOP;
            dsp_al <= 18'h00000;
            dsp_bl <= 18'h00000;
            dsp_ar <= 18'h00000;
            dsp_br <= 18'h00000;
        end
    end


    // MOVE AC VALUE TO RESULTS
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            smp_out_rdy <= 1'b0;
            smp_l_out   <= 18'h00000;
            smp_r_out   <= 18'h00000;
        end
        else if (tasks & MOV_RES_AC) begin
            smp_out_rdy <= 1'b1;
            smp_l_out   <= dsp_pl[36:34] == 3'h0 ? dsp_pl[33:16] :
                           dsp_pl[36:34] == 3'h7 ? dsp_pl[33:16] :
                           xy_l_dly_line[3];
            smp_r_out   <= dsp_pr[36:34] == 3'h0 ? dsp_pr[33:16] :
                           dsp_pr[36:34] == 3'h7 ? dsp_pr[33:16] :
                           xy_r_dly_line[3];
        end
        else begin
            smp_out_rdy <= 1'b0;
            smp_l_out     <= 18'h00000;
            smp_r_out     <= 18'h00000;
        end
    end
endmodule
