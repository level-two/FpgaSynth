// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: alu.v
// Description: ALU
// -----------------------------------------------------------------------------

`include "../globals.vh"

module alu(
    input                          clk              ,
    input                          reset            ,
    output      [   CLIENTS_N-1:0] client_cycle     ,
    output      [   CLIENTS_N-1:0] client_strobe    ,
    input       [   CLIENTS_N-1:0] client_ack       ,
    input       [   CLIENTS_N-1:0] client_stall     ,
    //input     [   CLIENTS_N-1:0] client_err       ,
    input       [ 9*CLIENTS_N-1:0] client_op        ,
    input       [18*CLIENTS_N-1:0] client_al        ,
    input       [18*CLIENTS_N-1:0] client_bl        ,
    input       [48*CLIENTS_N-1:0] client_cl        ,
    output      [48*CLIENTS_N-1:0] client_pl        ,
    input       [18*CLIENTS_N-1:0] client_ar        ,
    input       [18*CLIENTS_N-1:0] client_br        ,
    input       [48*CLIENTS_N-1:0] client_cr        ,
    output      [48*CLIENTS_N-1:0] client_pr        
);

    parameter CLIENTS_N = 2;
    parameter ALUS_N    = 2;
    parameter ALUS_W    = 1;

    wire [   ALUS_N-1:0] alu_strobe;
    wire [   ALUS_N-1:0] alu_cycle;
    wire [   ALUS_N-1:0] alu_ack;
    wire [   ALUS_N-1:0] alu_stall;
    wire [   ALUS_N-1:0] alu_err;
    wire [ 9*ALUS_N-1:0] alu_op;
    wire [18*ALUS_N-1:0] alu_al;
    wire [18*ALUS_N-1:0] alu_bl;
    wire [48*ALUS_N-1:0] alu_cl;
    wire [48*ALUS_N-1:0] alu_pl;
    wire [18*ALUS_N-1:0] alu_ar;
    wire [18*ALUS_N-1:0] alu_br;
    wire [48*ALUS_N-1:0] alu_cr;
    wire [48*ALUS_N-1:0] alu_pr;

    alu_nic_mul #(
        .CLIENTS_N     (CLIENTS_N          ),
        .ALUS_N        (ALUS_N             ),
        .ALUS_W        (ALUS_W             )
    ) alu_nic_mul_inst (
        .clk           (clk                ),
        .reset         (reset              ),

        .client_strobe (client_strobe      ),
        .client_cycle  (client_cycle       ),
        .client_ack    (client_ack         ),
        .client_stall  (client_stall       ),
        //.client_err  (client_err         ), // TBI
        .client_op     (client_op          ),
        .client_al     (client_al          ),
        .client_bl     (client_bl          ),
        .client_cl     (client_cl          ),
        .client_pl     (client_pl          ),
        .client_ar     (client_ar          ),
        .client_br     (client_br          ),
        .client_cr     (client_cr          ),
        .client_pr     (client_pr          ),

        .alu_strobe    (alu_strobe         ),
        .alu_cycle     (alu_cycle          ),
        .alu_ack       (alu_ack            ),
        .alu_stall     (alu_stall          ),
        //.alu_err     (alu_err            ), // TBI
        .alu_op        (alu_op             ),
        .alu_al        (alu_al             ),
        .alu_bl        (alu_bl             ),
        .alu_cl        (alu_cl             ),
        .alu_pl        (alu_pl             ),
        .alu_ar        (alu_ar             ),
        .alu_br        (alu_br             ),
        .alu_cr        (alu_cr             ),
        .alu_pr        (alu_pr             )
    );

    genvar i;
    generate for (i = 0; i < ALUS_N; i=i+1) begin : alu_core_block
        alu_core alu_core(
            .clk        (clk                     ),
            .reset      (reset                   ),
            .alu_strobe (alu_strobe[i]           ),
            .alu_cycle  (alu_cycle [i]           ),
            .alu_ack    (alu_ack   [i]           ),
            .alu_stall  (alu_stall [i]           ),
            //.alu_err  (alu_err   [i]           ), // TBI
            .alu_op     (alu_op    [ 9*i +:  9]  ),
            .alu_al     (alu_al    [18*i +: 18]  ),
            .alu_bl     (alu_bl    [18*i +: 18]  ),
            .alu_cl     (alu_cl    [48*i +: 48]  ),
            .alu_pl     (alu_pl    [48*i +: 48]  ),
            .alu_ar     (alu_ar    [18*i +: 18]  ),
            .alu_br     (alu_br    [18*i +: 18]  ),
            .alu_cr     (alu_cr    [48*i +: 48]  ),
            .alu_pr     (alu_pr    [48*i +: 48]  )
        );
    end endgenerate

endmodule
