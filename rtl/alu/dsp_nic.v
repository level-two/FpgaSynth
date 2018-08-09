// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: dsp_nic.v
// Description: Interconnection with arbitration for DSP clients
// -----------------------------------------------------------------------------

`include "globals.vh"

module dsp_nic (
    input                          clk,
    input                          reset,
                
    input       [ 8*CLIENTS_N-1:0] client_op,
                
    input       [18*CLIENTS_N-1:0] client_al,
    input       [18*CLIENTS_N-1:0] client_bl,
    input       [48*CLIENTS_N-1:0] client_cl,
    output      [48*CLIENTS_N-1:0] client_pl,
                
    input       [18*CLIENTS_N-1:0] client_ar,
    input       [18*CLIENTS_N-1:0] client_br,
    input       [48*CLIENTS_N-1:0] client_cr,
    output      [48*CLIENTS_N-1:0] client_pr,
                
    input       [   CLIENTS_N-1:0] client_req,
    output      [   CLIENTS_N-1:0] client_gnt,

    output      [ 7:0]             dsp_op,
    output      [17:0]             dsp_al,
    output      [17:0]             dsp_bl,
    output      [47:0]             dsp_cl,
    input       [47:0]             dsp_pl,
                                   
    output      [17:0]             dsp_ar,
    output      [17:0]             dsp_br,
    output      [47:0]             dsp_cr,
    input       [47:0]             dsp_pr,
                                   
    output                         dsp_req,
    input                          dsp_gnt
);

    parameter CLIENTS_N = 2;

    wire [CLIENTS_N-1:0] loc_client_gnt;
    arb_rr #(CLIENTS_N) arb_rr_inst
    (
        .clk    (clk                 ),
        .reset  (reset               ),
        .req    (client_req          ),
        .gnt    (loc_client_gnt      )
    );

    assign dsp_req    = client_req     & loc_client_gnt;
    assign client_gnt = loc_client_gnt & {CLENTS_N{dsp_gnt}};

    genvar i;

    always @(*) begin
        dsp_op    =  8'h0;
        dsp_al    = 17'h0;
        dsp_bl    = 17'h0;
        dsp_cl    = 47'h0;
        dsp_ar    = 17'h0;
        dsp_br    = 17'h0;
        dsp_cr    = 47'h0;

        generate for (i = 0; i < CLIENTS_N; i=i+1) begin : clients_defaults
            client_pl[48*(i+1)-1 : 48*i] = 47'h0;
            client_pr[48*(i+1)-1 : 48*i] = 47'h0;
        end endgenerate

        generate for (i = 0; i < CLIENTS_N; i=i+1) begin : clients_to_dsp_conn
            if (client_gnt[i]) begin
                dsp_op                       = client_op[ 8*(i+1)-1 :  8*i];
                dsp_al                       = client_al[18*(i+1)-1 : 18*i];
                dsp_bl                       = client_bl[18*(i+1)-1 : 18*i];
                dsp_cl                       = client_cl[48*(i+1)-1 : 48*i];
                dsp_ar                       = client_ar[18*(i+1)-1 : 18*i];
                dsp_br                       = client_br[18*(i+1)-1 : 18*i];
                dsp_cr                       = client_cr[48*(i+1)-1 : 48*i];
                client_pl[48*(i+1)-1 : 48*i] = dsp_pl;
                client_pr[48*(i+1)-1 : 48*i] = dsp_pr;
            end
        end endgenerate
    end
endmodule
