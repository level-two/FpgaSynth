// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: dsp_module.v
// Description: Instance of the DSP48A1 in the pipelined multiplier-postadder
//              mode
// -----------------------------------------------------------------------------

`include "globals.vh"

module dsp_module (
    input                          clk,
    input                          reset,
                
    input       [ 8*CLIENTS_N-1:0] op,
                
    input       [18*CLIENTS_N-1:0] al,
    input       [18*CLIENTS_N-1:0] bl,
    input       [48*CLIENTS_N-1:0] cl,
    output      [48*CLIENTS_N-1:0] pl,
                
    input       [18*CLIENTS_N-1:0] ar,
    input       [18*CLIENTS_N-1:0] br,
    input       [48*CLIENTS_N-1:0] cr,
    output      [48*CLIENTS_N-1:0] pr,
                
    input       [   CLIENTS_N-1:0] req,
    output      [   CLIENTS_N-1:0] gnt
);

    parameter DSPS_N    = 1; // TODO Implement arbiter for multiple DSPS
    parameter CLIENTS_N = 2;

    arb_rr #(CLIENTS_N) arb_rr_inst
    (
        .clk    (clk        ),
        .reset  (reset      ),
        .req    (req        ),
        .gnt    (gnt        )
    );

    wire gnt_for_dsp[DSPS_N][CLIENTS_N] = { {DSPS_N-1{0}}, gnt };

    // Client signals                    
    wire [ 7:0] client_op[CLIENTS_N];
    wire [17:0] client_al[CLIENTS_N];
    wire [17:0] client_bl[CLIENTS_N];
    wire [47:0] client_cl[CLIENTS_N];
    wire [47:0] client_pl[CLIENTS_N];
    wire [17:0] client_ar[CLIENTS_N];
    wire [17:0] client_br[CLIENTS_N];
    wire [47:0] client_cr[CLIENTS_N];
    wire [47:0] client_pr[CLIENTS_N];

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

    genvar i;
    genvar j;

    generate for (j = 0; j < CLIENTS_N; j=j+1) begin : clients_unpack
        assign client_op[j]          = op[ 8*(j+1)-1 :  8*j];
        assign client_al[j]          = al[18*(j+1)-1 : 18*j];
        assign client_bl[j]          = bl[18*(j+1)-1 : 18*j];
        assign client_cl[j]          = cl[48*(j+1)-1 : 48*j];
        assign client_ar[j]          = ar[18*(j+1)-1 : 18*j];
        assign client_br[j]          = br[18*(j+1)-1 : 18*j];
        assign client_cr[j]          = cr[48*(j+1)-1 : 48*j];
        assign pl[48*(j+1)-1 : 48*j] = client_pl[j];
        assign pr[48*(j+1)-1 : 48*j] = client_pr[j];
    end endgenerate

    always @(*) begin
        generate for (i = 0; i < DSPS_N; i=i+1) begin : dsp_signals_default
            dsp_op[i]    =  8'h0;
            dsp_al[i]    = 17'h0;
            dsp_bl[i]    = 17'h0;
            dsp_cl[i]    = 47'h0;
            dsp_ar[i]    = 17'h0;
            dsp_br[i]    = 17'h0;
            dsp_cr[i]    = 47'h0;
        end endgenerate

        generate for (j = 0; j < CLIENTS_N; j=j+1) begin : client_signals_default
            client_pl[j] = 47'h0;
            client_pr[j] = 47'h0;
        end endgenerate

        generate for (i = 0; i < DSPS_N; i=i+1) begin : dsp_signals_conn
            generate for (j = 0; j < CLIENTS_N; j=j+1) begin : clients_to_dsp_conn
                if (gnt_for_dsp[i][j]) begin
                    dsp_op   [i] = client_op[j];
                    dsp_al   [i] = client_al[j];
                    dsp_bl   [i] = client_bl[j];
                    dsp_cl   [i] = client_cl[j];
                    client_pl[j] = dsp_pl   [i];
                    dsp_ar   [i] = client_ar[j];
                    dsp_br   [i] = client_br[j];
                    dsp_cr   [i] = client_cr[j];
                    client_pr[j] = dsp_pr   [i];
                end
            end endgenerate
        end endgenerate
    end

    generate for (i = 0; i < DSPS_N; i=i+1) begin : dsp_inst
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
    end endgenerate
endmodule
