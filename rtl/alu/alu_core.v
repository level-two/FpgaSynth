// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: alu_core.v
// Description: Core of the ALU module
// -----------------------------------------------------------------------------

`include "../globals.vh"

module alu_core (
    input             clk             ,
    input             reset           ,

    // WISHBONE SLAVE INTERFACE
    input             alu_strobe      ,
    input             alu_cycle       ,
    output            alu_ack         ,
    output            alu_stall       ,
    //output          alu_err         , // TBI

    input      [ 8:0] alu_op          ,
    input      [17:0] alu_al          ,
    input      [17:0] alu_bl          ,
    input      [47:0] alu_cl          ,
    output     [47:0] alu_pl          ,
    input      [17:0] alu_ar          ,
    input      [17:0] alu_br          ,
    input      [47:0] alu_cr          ,
    output     [47:0] alu_pr
);

    wire alu_mode = alu_op[8];

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


    // SIN and COS calc
    reg [8:0]          taylor_function_sel;
    reg                taylor_do_calc;
    reg  signed [17:0] taylor_xl;
    reg  signed [17:0] taylor_xr;
    wire               taylor_calc_done;
    wire signed [17:0] taylor_resl;
    wire signed [17:0] taylor_resr;

    wire        [ 8:0] taylor_dsp_op;
    wire signed [17:0] taylor_dsp_al;
    wire signed [17:0] taylor_dsp_bl;
    wire signed [47:0] taylor_dsp_cl;
    wire signed [47:0] taylor_dsp_pl;
    wire signed [17:0] taylor_dsp_ar;
    wire signed [17:0] taylor_dsp_br;
    wire signed [47:0] taylor_dsp_cr;
    wire signed [47:0] taylor_dsp_pr;

    // 1/(1+x) calc
    reg [8:0]          taylor1_function_sel;
    reg                taylor1_do_calc;
    reg  signed [17:0] taylor1_xl;
    reg  signed [17:0] taylor1_xr;
    wire               taylor1_calc_done;
    wire signed [17:0] taylor1_resl;
    wire signed [17:0] taylor1_resr;

    wire        [ 8:0] taylor1_dsp_op;
    wire signed [17:0] taylor1_dsp_al;
    wire signed [17:0] taylor1_dsp_bl;
    wire signed [47:0] taylor1_dsp_cl;
    wire signed [47:0] taylor1_dsp_pl;
    wire signed [17:0] taylor1_dsp_ar;
    wire signed [17:0] taylor1_dsp_br;
    wire signed [47:0] taylor1_dsp_cr;
    wire signed [47:0] taylor1_dsp_pr;

    // DSP signals
    wire [ 8:0] dsp_op;
    wire [17:0] dsp_al;
    wire [17:0] dsp_bl;
    wire [47:0] dsp_cl;
    wire [47:0] dsp_pl;
    wire [17:0] dsp_ar;
    wire [17:0] dsp_br;
    wire [47:0] dsp_cr;
    wire [47:0] dsp_pr;


    assign dsp_op         = alu_op | taylor_dsp_op | taylor1_dsp_op;
    assign dsp_al         = alu_al | taylor_dsp_al | taylor1_dsp_al;
    assign dsp_bl         = alu_bl | taylor_dsp_bl | taylor1_dsp_bl;
    assign dsp_cl         = alu_cl | taylor_dsp_cl | taylor1_dsp_cl;
    assign taylor_dsp_pl  = dsp_pl;
    assign taylor1_dsp_pl = dsp_pl;
    assign dsp_ar         = alu_ar | taylor_dsp_ar | taylor1_dsp_ar;
    assign dsp_br         = alu_br | taylor_dsp_br | taylor1_dsp_br;
    assign dsp_cr         = alu_cr | taylor_dsp_cr | taylor1_dsp_cr;
    assign taylor_dsp_pr  = dsp_pr;
    assign taylor1_dsp_pr = dsp_pr;

    assign alu_pl         = dsp_pl |
                            { {14{taylor_resl [17]}}, taylor_resl [17:0], 16'h0} |
                            { {14{taylor1_resl[17]}}, taylor1_resl[17:0], 16'h0};
    assign alu_pr         = dsp_pr |
                            { {14{taylor_resr [17]}}, taylor_resr [17:0], 16'h0} |
                            { {14{taylor1_resr[17]}}, taylor1_resr[17:0], 16'h0};

    reg busy;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            busy <= 1'b0;
        end else if (taylor_do_calc || taylor1_do_calc) begin
            busy <= 1'b1;
        end else if (taylor_calc_done || taylor1_calc_done) begin
            busy <= 1'b0;
        end
    end


    assign alu_ack   = ack_q[2] | taylor_calc_done | taylor1_calc_done;
    assign alu_stall = busy & ~alu_ack;


    always @(*) begin
        taylor_function_sel  = 'h0;
        taylor_do_calc       = 1'b0;
        taylor_xl            = 18'h0;
        taylor_xr            = 18'h0;
        taylor1_function_sel = 'h0;
        taylor1_do_calc      = 1'b0;
        taylor1_xl           = 18'h0;
        taylor1_xr           = 18'h0;

        if (!alu_cycle) begin
            // do nothing
        end else if (alu_mode == `ALU_MODE_DSP) begin
            // do nothing
        end else if (alu_op == `ALU_FUNC_SIN) begin
            taylor_function_sel  = `ALU_FUNC_SIN;
            taylor_do_calc       = alu_strobe;
            taylor_xl            = alu_al;
            taylor_xr            = alu_ar;
        end else if (alu_op == `ALU_FUNC_COS) begin
            taylor_function_sel  = `ALU_FUNC_COS;
            taylor_do_calc       = alu_strobe;
            taylor_xl            = alu_al;
            taylor_xr            = alu_ar;
        end else if (alu_op == `ALU_FUNC_INV_1_PLUS_X) begin
            taylor1_function_sel = `ALU_FUNC_INV_1_PLUS_X;
            taylor1_do_calc      = alu_strobe;
            taylor1_xl           = alu_al;
            taylor1_xr           = alu_ar;
        end
    end


    alu_taylor_calc alu_taylor_calc (
        .clk            (clk                 ),
        .reset          (reset               ),
        .func_sel       (taylor_function_sel ),
        .do_calc        (taylor_do_calc      ),
        .xl             (taylor_xl           ),
        .xr             (taylor_xr           ),
        .calc_done      (taylor_calc_done    ),
        .resl           (taylor_resl         ),
        .resr           (taylor_resr         ),
        .dsp_op         (taylor_dsp_op       ),
        .dsp_al         (taylor_dsp_al       ),
        .dsp_bl         (taylor_dsp_bl       ),
        .dsp_cl         (taylor_dsp_cl       ),
        .dsp_pl         (taylor_dsp_pl       ),
        .dsp_ar         (taylor_dsp_ar       ),
        .dsp_br         (taylor_dsp_br       ),
        .dsp_cr         (taylor_dsp_cr       ),
        .dsp_pr         (taylor_dsp_pr       )
    );


    alu_taylor_calc_1 alu_taylor1_calc (
        .clk            (clk                 ),
        .reset          (reset               ),
        .func_sel       (taylor1_function_sel),
        .do_calc        (taylor1_do_calc     ),
        .xl             (taylor1_xl          ),
        .xr             (taylor1_xr          ),
        .calc_done      (taylor1_calc_done   ),
        .resl           (taylor1_resl        ),
        .resr           (taylor1_resr        ),
        .dsp_op         (taylor1_dsp_op      ),
        .dsp_al         (taylor1_dsp_al      ),
        .dsp_bl         (taylor1_dsp_bl      ),
        .dsp_cl         (taylor1_dsp_cl      ),
        .dsp_pl         (taylor1_dsp_pl      ),
        .dsp_ar         (taylor1_dsp_ar      ),
        .dsp_br         (taylor1_dsp_br      ),
        .dsp_cr         (taylor1_dsp_cr      ),
        .dsp_pr         (taylor1_dsp_pr      )
    );

    // DSP
    alu_dsp48a1 alu_dsp48a1_l (
        .clk    (clk             ),
        .reset  (reset           ),
        .op     (dsp_op          ),
        .a      (dsp_al          ),
        .b      (dsp_bl          ),
        .c      (dsp_cl          ),
        .p      (dsp_pl          )
    );

    alu_dsp48a1 alu_dsp48a1_r (
        .clk    (clk            ),
        .reset  (reset          ),
        .op     (dsp_op         ),
        .a      (dsp_ar         ),
        .b      (dsp_br         ),
        .c      (dsp_cr         ),
        .p      (dsp_pr         )
    );
endmodule
