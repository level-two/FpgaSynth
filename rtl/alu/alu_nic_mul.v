// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: alu_nic_mul.v
// Description: Interconnection with arbitration for DSP clients
// -----------------------------------------------------------------------------

`include "globals.vh"

module alu_nic_mul (
    input                     clk           ,
    input                     reset         ,

    input  [   CLIENTS_N-1:0] client_cycle  ,
    input  [   CLIENTS_N-1:0] client_strobe ,
    output [   CLIENTS_N-1:0] client_ack    ,
    output [   CLIENTS_N-1:0] client_stall  ,
    //output[  CLIENTS_N-1:0] client_err    ,
    input  [   CLIENTS_N-1:0] client_mode   ,
    input  [ 8*CLIENTS_N-1:0] client_op     ,
    input  [18*CLIENTS_N-1:0] client_al     ,
    input  [18*CLIENTS_N-1:0] client_bl     ,
    input  [48*CLIENTS_N-1:0] client_cl     ,
    output [48*CLIENTS_N-1:0] client_pl     ,
    input  [18*CLIENTS_N-1:0] client_ar     ,
    input  [18*CLIENTS_N-1:0] client_br     ,
    input  [48*CLIENTS_N-1:0] client_cr     ,
    output [48*CLIENTS_N-1:0] client_pr     ,

    output [      ALUS_N-1:0] alu_strobe    ,
    output [      ALUS_N-1:0] alu_cycle     ,
    input  [      ALUS_N-1:0] alu_ack       ,
    input  [      ALUS_N-1:0] alu_stall     ,
    //input[      ALUS_N-1:0] alu_err       ,
    output [      ALUS_N-1:0] alu_mode      ,
    output [    8*ALUS_N-1:0] alu_op        ,
    output [   18*ALUS_N-1:0] alu_al        ,
    output [   18*ALUS_N-1:0] alu_bl        ,
    output [   48*ALUS_N-1:0] alu_cl        ,
    input  [   48*ALUS_N-1:0] alu_pl        ,
    output [   18*ALUS_N-1:0] alu_ar        ,
    output [   18*ALUS_N-1:0] alu_br        ,
    output [   48*ALUS_N-1:0] alu_cr        ,
    input  [   48*ALUS_N-1:0] alu_pr
);

    parameter CLIENTS_N = 2;
    parameter ALUS_N    = 2;
    parameter ALUS_W    = 1;

    wire [CLIENTS_N-1:0]        gnt_val;
    wire [CLIENTS_N*ALUS_N-1:0] gnt_id;

    arb_mul #(
        .PORTS_N    (CLIENTS_N       ),
        .GNTS_N     (ALUS_N          ),
        .GNTS_W     (ALUS_W          )
    ) arb_mul_inst (
        .clk        (clk             ),
        .reset      (reset           ),
        .req        (client_cycle    ),
        .gnt        (gnt_val         ),
        .gnt_id     (gnt_id          )
    );

    genvar j;

    always @(*) begin
        client_pl    = {CLEINTS_N{47'h0}};
        client_pr    = {CLEINTS_N{47'h0}};

        client_stall = {CLIENTS_N{ 1'b0}};
        client_ack   = {CLIENTS_N{ 1'b0}};
        //client_err = {CLIENTS_N{ 1'b0}};

        alu_strobe   = {   ALUS_N{ 1'b0}};
        alu_cycle    = {   ALUS_N{ 1'b0}};
        alu_mode     = {   ALUS_N{ 1'b0}};
        alu_op       = {   ALUS_N{ 8'h0}};
        alu_al       = {   ALUS_N{17'h0}};
        alu_bl       = {   ALUS_N{17'h0}};
        alu_cl       = {   ALUS_N{47'h0}};
        alu_ar       = {   ALUS_N{17'h0}};
        alu_br       = {   ALUS_N{17'h0}};
        alu_cr       = {   ALUS_N{47'h0}};

        generate for (j = 0; j < CLIENTS_N; j=j+1) begin : conn_cl_to_dsp
            client_stall[j] = client_cycle[j] & ~gnt_val[j];

            if (gnt_val[j]) begin : on_gnt
                integer alu_id           = gnt_id       [ALUS_W*j +: ALUS_W];

                client_ack  [         j] = alu_ack      [    alu_id];
                client_stall[         j] = alu_stall    [    alu_id];
                //client_err[         j] = alu_err      [    alu_id];
                client_pl   [48*j +: 48] = alu_pl       [    alu_id];
                client_pr   [48*j +: 48] = alu_pr       [    alu_id];

                alu_strobe  [    alu_id] = client_strobe[         j];
                alu_cycle   [    alu_id] = client_cycle [         j];
                alu_mode    [    alu_id] = client_mode  [         j];
                alu_op      [    alu_id] = client_op    [ 8*j +:  8];
                alu_al      [    alu_id] = client_al    [18*j +: 18];
                alu_bl      [    alu_id] = client_bl    [18*j +: 18];
                alu_cl      [    alu_id] = client_cl    [48*j +: 48];
                alu_ar      [    alu_id] = client_ar    [18*j +: 18];
                alu_br      [    alu_id] = client_br    [18*j +: 18];
                alu_cr      [    alu_id] = client_cr    [48*j +: 48];
            end
        end endgenerate
    end
endmodule
