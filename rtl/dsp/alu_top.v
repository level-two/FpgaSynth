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

module alu_top (
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

    reg [2:0] ack_q;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            ack_q[2:0] <= 1'b0;
        end else begin
            if (alu_cycle && alu_strobe && alu_mode == `ALU_MODE_DSP) begin
                ack_q[0] <= 1'b1;
            end else begin
                ack_q[0] <= 1'b0;
            end

            ack_q[2:1] <= ack_q[1:0];
        end
    end


    always @(*) begin
        if (!alu_cycle) begin
            dsp_op         <=  8'h0;
            dsp_al         <= 18'h0;
            dsp_bl         <= 18'h0;
            dsp_cl         <= 48'h0;
            dsp_ar         <= 18'h0;
            dsp_br         <= 18'h0;
            dsp_cr         <= 48'h0;
            alu_pl         <= 48'h0;
            alu_pr         <= 48'h0;
            taylor_dsp_pl  <= 48'h0;
            taylor_dsp_pr  <= 48'h0;
            taylor1_dsp_pl <= 48'h0;
            taylor1_dsp_pr <= 48'h0;
        end
        else if (alu_mode == `ALU_MODE_DSP) begin
            dsp_op         <= alu_op;
            dsp_al         <= alu_al;
            dsp_bl         <= alu_bl;
            dsp_cl         <= alu_cl;
            dsp_ar         <= alu_ar;
            dsp_br         <= alu_br;
            dsp_cr         <= alu_cr;
            alu_pl         <= dsp_pl;
            alu_pr         <= dsp_pr;
        end
        else if (alu_op == `ALU_FUNC_SIN || alu_op == `ALU_FUNC_COS) begin
            dsp_op         <= taylor_dsp_op;
            dsp_al         <= taylor_dsp_al;
            dsp_bl         <= taylor_dsp_bl;
            dsp_cl         <= taylor_dsp_cl;
            dsp_ar         <= taylor_dsp_ar;
            dsp_br         <= taylor_dsp_br;
            dsp_cr         <= taylor_dsp_cr;
            taylor_dsp_pl  <= dsp_pl;
            taylor_dsp_pr  <= dsp_pr;
        end
        else if (alu_op == `ALU_FUNC_INV_1_PLUS_X) begin
            dsp_op         <= taylor1_dsp_op;
            dsp_al         <= taylor1_dsp_al;
            dsp_bl         <= taylor1_dsp_bl;
            dsp_cl         <= taylor1_dsp_cl;
            dsp_ar         <= taylor1_dsp_ar;
            dsp_br         <= taylor1_dsp_br;
            dsp_cr         <= taylor1_dsp_cr;
            taylor1_dsp_pl <= dsp_pl;
            taylor1_dsp_pr <= dsp_pr;
        end
        else begin
            dsp_op         <=  8'h0;
            dsp_al         <= 18'h0;
            dsp_bl         <= 18'h0;
            dsp_cl         <= 48'h0;
            dsp_ar         <= 18'h0;
            dsp_br         <= 18'h0;
            dsp_cr         <= 48'h0;
            alu_pl         <= 48'h0;
            alu_pr         <= 48'h0;
            taylor_dsp_pl  <= 48'h0;
            taylor_dsp_pr  <= 48'h0;
            taylor1_dsp_pl <= 48'h0;
            taylor1_dsp_pr <= 48'h0;
        end
    end


    always @(*) begin
        if (!alu_cycle) begin
            alu_ack <= 1'b0;
        end
        else if (alu_mode == `ALU_MODE_DSP) begin
            alu_ack <= ack_q[2];
        end
        else if (alu_op == `ALU_FUNC_SIN || alu_op == `ALU_FUNC_COS) begin
            alu_ack <= taylor_calc_done;
        end
        else if (alu_op == `ALU_FUNC_INV_1_PLUS_X) begin
            alu_ack <= taylor1_calc_done;
        end
        else begin
            alu_ack <= 1'b0;
        end
    end


    // SIN and COS calc
    reg [2:0]          taylor_function_sel;
    reg                taylor_do_calc;
    reg  signed [17:0] taylor_xl;
    reg  signed [17:0] taylor_xr;
    wire               taylor_calc_done;
    wire signed [17:0] taylor_resl;
    wire signed [17:0] taylor_resr;

    wire        [ 7:0] taylor_dsp_op;
    wire signed [17:0] taylor_dsp_al;
    wire signed [17:0] taylor_dsp_bl;
    wire signed [47:0] taylor_dsp_cl;
    wire signed [47:0] taylor_dsp_pl;
    wire signed [17:0] taylor_dsp_ar;
    wire signed [17:0] taylor_dsp_br;
    wire signed [47:0] taylor_dsp_cr;
    wire signed [47:0] taylor_dsp_pr;


    alu_taylor_calc alu_taylor_calc (
        .clk            (clk                 ),
        .reset          (reset               ),
        .func_sel       (taylor_func_sel     ),
        .do_calc        (taylor_do_calc      ),
        .xl             (taylor_xl           ),
        .xr             (taylor_xr           ),
        .calc_done      (taylor_calc_done    ),
        .resl           (taylor_resl         ),
        .resr           (taylor_resr         ),
        .dsp_op         (taylor_dsp_op       ),
        .dsp_a_l        (taylor_dsp_al       ),
        .dsp_b_l        (taylor_dsp_bl       ),
        .dsp_c_l        (taylor_dsp_cl       ),
        .dsp_p_l        (taylor_dsp_pl       ),
        .dsp_a_r        (taylor_dsp_ar       ),
        .dsp_b_r        (taylor_dsp_br       ),
        .dsp_c_r        (taylor_dsp_cr       ),
        .dsp_p_r        (taylor_dsp_pr       )
    );


    // 1/(1+x) calc
    reg [2:0]          taylor1_function_sel;
    reg                taylor1_do_calc;
    reg  signed [17:0] taylor1_xl;
    reg  signed [17:0] taylor1_xr;
    wire               taylor1_calc_done;
    wire signed [17:0] taylor1_resl;
    wire signed [17:0] taylor1_resr;

    wire        [ 7:0] taylor1_dsp_op;
    wire signed [17:0] taylor1_dsp_al;
    wire signed [17:0] taylor1_dsp_bl;
    wire signed [47:0] taylor1_dsp_cl;
    wire signed [47:0] taylor1_dsp_pl;
    wire signed [17:0] taylor1_dsp_ar;
    wire signed [17:0] taylor1_dsp_br;
    wire signed [47:0] taylor1_dsp_cr;
    wire signed [47:0] taylor1_dsp_pr;


    alu_taylor_calc_1 alu_taylor1_calc (
        .clk            (clk                 ),
        .reset          (reset               ),
        .func_sel       (taylor1_func_sel    ),
        .do_calc        (taylor1_do_calc     ),
        .xl             (taylor1_xl          ),
        .xr             (taylor1_xr          ),
        .calc_done      (taylor1_calc_done   ),
        .resl           (taylor1_resl        ),
        .resr           (taylor1_resr        ),
        .dsp_op         (taylor1_dsp_op      ),
        .dsp_a_l        (taylor1_dsp_al      ),
        .dsp_b_l        (taylor1_dsp_bl      ),
        .dsp_c_l        (taylor1_dsp_cl      ),
        .dsp_p_l        (taylor1_dsp_pl      ),
        .dsp_a_r        (taylor1_dsp_ar      ),
        .dsp_b_r        (taylor1_dsp_br      ),
        .dsp_c_r        (taylor1_dsp_cr      ),
        .dsp_p_r        (taylor1_dsp_pr      )
    );


    // DSP signals
    wire [ 7:0] dsp_op;
    wire [17:0] dsp_al;
    wire [17:0] dsp_bl;
    wire [47:0] dsp_cl;
    wire [47:0] dsp_pl;
    wire [17:0] dsp_ar;
    wire [17:0] dsp_br;
    wire [47:0] dsp_cr;
    wire [47:0] dsp_pr;

    // DSP
    dsp48a1_inst dsp48a1_l_inst (
        .clk    (clk             ),
        .reset  (reset           ),
        .op     (dsp_op          ),
        .a      (dsp_al          ),
        .b      (dsp_bl          ),
        .c      (dsp_cl          ),
        .p      (dsp_pl          )
    );

    dsp48a1_inst dsp48a1_r_inst (
        .clk    (clk            ),
        .reset  (reset          ),
        .op     (dsp_op         ),
        .a      (dsp_ar         ),
        .b      (dsp_br         ),
        .c      (dsp_cr         ),
        .p      (dsp_pr         )
    );
endmodule
