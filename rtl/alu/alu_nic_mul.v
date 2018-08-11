// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: alu_nic_mul.v
// Description: Interconnection with arbitration for DSP clients
// -----------------------------------------------------------------------------

`include "../globals.vh"

module alu_nic_mul (
    input                         clk           ,
    input                         reset         ,

    input      [   CLIENTS_N-1:0] client_cycle  ,
    input      [   CLIENTS_N-1:0] client_strobe ,
    output reg [   CLIENTS_N-1:0] client_ack    ,
    output reg [   CLIENTS_N-1:0] client_stall  ,
  //output reg [  CLIENTS_N-1:0] client_err    ,
    input      [ 9*CLIENTS_N-1:0] client_op     ,
    input      [18*CLIENTS_N-1:0] client_al     ,
    input      [18*CLIENTS_N-1:0] client_bl     ,
    input      [48*CLIENTS_N-1:0] client_cl     ,
    output reg [48*CLIENTS_N-1:0] client_pl     ,
    input      [18*CLIENTS_N-1:0] client_ar     ,
    input      [18*CLIENTS_N-1:0] client_br     ,
    input      [48*CLIENTS_N-1:0] client_cr     ,
    output reg [48*CLIENTS_N-1:0] client_pr     ,

    output reg [      ALUS_N-1:0] alu_strobe    ,
    output reg [      ALUS_N-1:0] alu_cycle     ,
    input      [      ALUS_N-1:0] alu_ack       ,
    input      [      ALUS_N-1:0] alu_stall     ,
  //input      [      ALUS_N-1:0] alu_err       ,
    output reg [    9*ALUS_N-1:0] alu_op        ,
    output reg [   18*ALUS_N-1:0] alu_al        ,
    output reg [   18*ALUS_N-1:0] alu_bl        ,
    output reg [   48*ALUS_N-1:0] alu_cl        ,
    input      [   48*ALUS_N-1:0] alu_pl        ,
    output reg [   18*ALUS_N-1:0] alu_ar        ,
    output reg [   18*ALUS_N-1:0] alu_br        ,
    output reg [   48*ALUS_N-1:0] alu_cr        ,
    input      [   48*ALUS_N-1:0] alu_pr
);

    parameter CLIENTS_N = 2;
    parameter ALUS_N    = 2;
    parameter ALUS_W    = 1;

    wire [CLIENTS_N-1:0]        gnt_val;
    wire [CLIENTS_N*ALUS_W-1:0] gnt_id;

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

    always @(*) begin : nic_alw
        integer j;

        alu_strobe   = {   ALUS_N{ 1'b0}};
        alu_cycle    = {   ALUS_N{ 1'b0}};
        alu_op       = {   ALUS_N{ 9'h0}};
        alu_al       = {   ALUS_N{17'h0}};
        alu_bl       = {   ALUS_N{17'h0}};
        alu_cl       = {   ALUS_N{47'h0}};
        alu_ar       = {   ALUS_N{17'h0}};
        alu_br       = {   ALUS_N{17'h0}};
        alu_cr       = {   ALUS_N{47'h0}};

        for (j = 0; j < CLIENTS_N; j=j+1) begin : nic_for
            client_pl   [48*j +: 48] = 48'h0;
            client_pr   [48*j +: 48] = 48'h0;

            client_ack  [j         ] = 1'b0;
            //client_err[j         ] = 1'b0;
            client_stall[j         ] = client_cycle[j] & ~gnt_val[j];

            if (gnt_val[j]) begin : on_gnt
                reg [ALUS_W-1:0] id;

                id = gnt_id[ALUS_W*j +: ALUS_W];

                client_ack  [          j] = alu_ack      [         id];
                client_stall[          j] = alu_stall    [         id];
                //client_err[          j] = alu_err      [         id];
                client_pl   [ 48*j +: 48] = alu_pl       [48*id +: 48];
                client_pr   [ 48*j +: 48] = alu_pr       [48*id +: 48];

                alu_strobe  [         id] = client_strobe[          j];
                alu_cycle   [         id] = client_cycle [          j];
                alu_op      [ 9*id +:  9] = client_op    [  9*j +:  9];
                alu_al      [18*id +: 18] = client_al    [ 18*j +: 18];
                alu_bl      [18*id +: 18] = client_bl    [ 18*j +: 18];
                alu_cl      [48*id +: 48] = client_cl    [ 48*j +: 48];
                alu_ar      [18*id +: 18] = client_ar    [ 18*j +: 18];
                alu_br      [18*id +: 18] = client_br    [ 18*j +: 18];
                alu_cr      [48*id +: 48] = client_cr    [ 48*j +: 48];
            end
        end // for
    end // always
endmodule
