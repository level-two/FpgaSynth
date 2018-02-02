// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: alu_top.v
// Description: Top of the ALU module
// -----------------------------------------------------------------------------

`include "globals.vh"

module alu_nic_mul (
    input             clk             ,
    input             reset           ,

    // WISHBONE SLAVE INTERFACE
    input             alu_strobe      ,
    input             alu_cycle       ,
    output            alu_ack         ,
    output            alu_stall       ,
    //output          alu_err         , // TBI

    input             alu_mode        ,
    input  [ 7:0]     alu_op          ,
    input  [17:0]     alu_al          ,
    input  [17:0]     alu_bl          ,
    input  [47:0]     alu_cl          ,
    output [47:0]     alu_pl          ,
    input  [17:0]     alu_ar          ,
    input  [17:0]     alu_br          ,
    input  [47:0]     alu_cr          ,
    output [47:0]     alu_pr
);


    always @(posedge reset or posedge clk) begin
        if (reset) begin
        end else if (alu_cycle && alu_strobe && alu_mode == `ALU_MODE_DSP) begin
            ack_q[0] <= 1'b1;
        end
        else begin
            ack_q[0] <= 1'b0;
        end
    end





// if alu_is_func == 1 - command for function module
// if alu_is_func == 0 - command for DSP


    // Taylor
    reg                taylor_do_calc;
    reg [2:0]          taylor_function_sel;
    reg  signed [17:0] taylor_x_in;
    wire               taylor_calc_done;
    wire signed [17:0] taylor_result;
    wire [91:0]        taylor_dsp_ins_flat;

    alu_taylor_calc alu_taylor_calc (
        .clk            (clk                 ),
        .reset          (reset               ),
        .do_calc        (taylor_do_calc      ),
        .func_sel       (taylor_function_sel ),
        .x_in           (taylor_x_in         ),
        .calc_done      (taylor_calc_done    ),
        .result         (taylor_result       ),
        .dsp_ins_flat   (taylor_dsp_ins_flat ),
        .dsp_outs_flat  (dsp_outs_flat       )
    );


    // Taylor 1
    reg                taylor_1_do_calc;
    reg [2:0]          taylor_1_function_sel;
    reg  signed [17:0] taylor_1_x_in;
    wire               taylor_1_calc_done;
    wire signed [17:0] taylor_1_result;
    wire [91:0]        taylor_1_dsp_ins_flat;

    alu_taylor_calc_1 alu_taylor_calc_1 (
        .clk            (clk                   ),
        .reset          (reset                 ),
        .do_calc        (taylor_1_do_calc      ),
        .func_sel       (taylor_1_function_sel ),
        .x_in           (taylor_1_x_in         ),
        .calc_done      (taylor_1_calc_done    ),
        .result         (taylor_1_result       ),
        .dsp_ins_flat   (taylor_1_dsp_ins_flat ),
        .dsp_outs_flat  (dsp_outs_flat         )
    );

    // DSP signals                    
    wire [ 7:0] dsp_op[DSPS_N];
    wire [17:0] dsp_al[DSPS_N];
    wire [17:0] dsp_bl[DSPS_N];
    wire [47:0] dsp_cl[DSPS_N];
    wire [47:0] dsp_pl[DSPS_N];
    wire [17:0] dsp_ar[DSPS_N];
    wire [17:0] dsp_br[DSPS_N];
    wire [47:0] dsp_cr[DSPS_N];
    wire [47:0] dsp_pr[DSPS_N];

    // DSP
    dsp48a1_inst dsp48a1_l_inst (
        .clk    (clk             ),
        .reset  (reset           ),
        .op     (dsp_op[i]       ),
        .a      (dsp_al[i]       ),
        .b      (dsp_bl[i]       ),
        .c      (dsp_cl[i]       ),
        .p      (dsp_pl[i]       )
    );

    dsp48a1_inst dsp48a1_r_inst (
        .clk    (clk            ),
        .reset  (reset          ),
        .op     (dsp_op[i]      ),
        .a      (dsp_ar[i]      ),
        .b      (dsp_br[i]      ),
        .c      (dsp_cr[i]      ),
        .p      (dsp_pr[i]      )
    );


endmodule
