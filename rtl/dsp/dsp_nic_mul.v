// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: dsp_nic_mul.v
// Description: Interconnection with arbitration for DSP clients
// -----------------------------------------------------------------------------

`include "globals.vh"

module dsp_nic_mul (
    input                     clk,
    input                     reset,
           
    input  [ 8*CLIENTS_N-1:0] client_op,
    input  [18*CLIENTS_N-1:0] client_al,
    input  [18*CLIENTS_N-1:0] client_bl,
    input  [48*CLIENTS_N-1:0] client_cl,
    output [48*CLIENTS_N-1:0] client_pl,
    input  [18*CLIENTS_N-1:0] client_ar,
    input  [18*CLIENTS_N-1:0] client_br,
    input  [48*CLIENTS_N-1:0] client_cr,
    output [48*CLIENTS_N-1:0] client_pr,

    output [ 8*DSPS_N-1   :0] dsp_op,
    output [18*DSPS_N-1   :0] dsp_al,
    output [18*DSPS_N-1   :0] dsp_bl,
    output [48*DSPS_N-1   :0] dsp_cl,
    input  [48*DSPS_N-1   :0] dsp_pl,
    output [18*DSPS_N-1   :0] dsp_ar,
    output [18*DSPS_N-1   :0] dsp_br,
    output [48*DSPS_N-1   :0] dsp_cr,
    input  [48*DSPS_N-1   :0] dsp_pr,

    input  [CLIENTS_N-1   :0] req,
    output [CLIENTS_N-1   :0] gnt
);

    parameter DSPS_N    = 1; // TODO Implement arbiter for multiple DSPS
    parameter CLIENTS_N = 2;
    
    wire gnt_matrix[DSPS_N * CLIENTS_N];

    arb_rr #(CLIENTS_N, DSPS_N) arb_rr_inst
    (
        .clk        (clk             ),
        .reset      (reset           ),
        .req        (req             ),
        .gnt_matrix (gnt_matrix      ) // gnt_matrix[CLIENTS_N][DSPS_N]
    );

    genvar i;
    genvar j;

    always @(*) begin
        gnt    = {CLEINTS_N{1'h0};
        dsp_op = {DSPS_N{8'h0};
        dsp_al = {DSPS_N{17'h0};
        dsp_bl = {DSPS_N{17'h0};
        dsp_cl = {DSPS_N{47'h0};
        dsp_ar = {DSPS_N{17'h0};
        dsp_br = {DSPS_N{17'h0};
        dsp_cr = {DSPS_N{47'h0};
        cl_pl  = {CLEINTS_N{47'h0};
        cl_pr  = {CLEINTS_N{47'h0};

        generate for (i = 0; i < DSPS_N; i=i+1) begin : conn_dsp_signals
            generate for (j = 0; j < CLIENTS_N; j=j+1) begin : conn_cl_to_dsp
                if (gnt_matrix[i*CLIENTS_N+j]) begin
                    gnt[j] = 1'b1;
                    dsp_op[i] = client_op[ 8*(j+1)-1 :  8*j];
                    dsp_al[i] = client_al[18*(j+1)-1 : 18*j];
                    dsp_bl[i] = client_bl[18*(j+1)-1 : 18*j];
                    dsp_cl[i] = client_cl[48*(j+1)-1 : 48*j];
                    dsp_ar[i] = client_ar[18*(j+1)-1 : 18*j];
                    dsp_br[i] = client_br[18*(j+1)-1 : 18*j];
                    dsp_cr[i] = client_cr[48*(j+1)-1 : 48*j];
                    client_pl[48*(j+1)-1 : 48*j] = dsp_pl[i];
                    client_pr[48*(j+1)-1 : 48*j] = dsp_pr[i];
                end
            end endgenerate
        end endgenerate
    end
endmodule
