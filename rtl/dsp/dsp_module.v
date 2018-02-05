// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: int_alu_module.v
// Description: Instance of the DSP48A1 in the pipelined multiplier-postadder
//              mode
// -----------------------------------------------------------------------------

`include "globals.vh"

module int_alu_module (
    input                          clk,
    input                          reset,
                
    input       [ 8*CLIENTS_N-1:0] alu_op,
                
    input       [18*CLIENTS_N-1:0] alu_al,
    input       [18*CLIENTS_N-1:0] alu_bl,
    input       [48*CLIENTS_N-1:0] alu_cl,
    output      [48*CLIENTS_N-1:0] alu_pl,
                
    input       [18*CLIENTS_N-1:0] alu_ar,
    input       [18*CLIENTS_N-1:0] alu_br,
    input       [48*CLIENTS_N-1:0] alu_cr,
    output      [48*CLIENTS_N-1:0] alu_pr,
                
    input       [   CLIENTS_N-1:0] alu_req,
    output      [   CLIENTS_N-1:0] alu_gnt
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
    wire [ 7:0] int_alu_op[DSPS_N];
    wire [17:0] int_alu_al[DSPS_N];
    wire [17:0] int_alu_bl[DSPS_N];
    wire [47:0] int_alu_cl[DSPS_N];
    wire [47:0] int_alu_pl[DSPS_N];
    wire [17:0] int_alu_ar[DSPS_N];
    wire [17:0] int_alu_br[DSPS_N];
    wire [47:0] int_alu_cr[DSPS_N];
    wire [47:0] int_alu_pr[DSPS_N];

    genvar i;
    generate for (i = 0; i < CLIENTS_N; i=i+1) begin : clients_unpack
        assign client_op[i] = alu_op[ 8*(i+1)-1 :  8*i];
        assign client_al[i] = alu_al[18*(i+1)-1 : 18*i];
        assign client_bl[i] = alu_bl[18*(i+1)-1 : 18*i];
        assign client_cl[i] = alu_cl[48*(i+1)-1 : 48*i];
        assign client_ar[i] = alu_ar[18*(i+1)-1 : 18*i];
        assign client_br[i] = alu_br[18*(i+1)-1 : 18*i];
        assign client_cr[i] = alu_cr[48*(i+1)-1 : 48*i];
        assign alu_pl[48*(i+1)-1 : 48*i] = client_pl[i];
        assign alu_pr[48*(i+1)-1 : 48*i] = client_pr[i];
    end endgenerate

    integer j;
    integer k;
    always @(*) begin
        for (j = 0; j < DSPS_N; j=j+1) begin : int_alu_signals_default
            int_alu_op[j]    =  8'h0;
            int_alu_al[j]    = 17'h0;
            int_alu_bl[j]    = 17'h0;
            int_alu_cl[j]    = 47'h0;
            int_alu_ar[j]    = 17'h0;
            int_alu_br[j]    = 17'h0;
            int_alu_cr[j]    = 47'h0;
        end

        for (j = 0; j < CLIENTS_N; j=j+1) begin : client_signals_default
            client_pl[j] = 47'h0;
            client_pr[j] = 47'h0;
        end

        for (k = 0; k < DSPS_N; k=k+1) begin : int_alu_signals_conn
            for (j = 0; j < CLIENTS_N; j=j+1) begin : clients_to_int_alu_conn
                if (gnt_for_dsp[k][j]) begin
                    int_alu_op   [k] = client_op [j];
                    int_alu_al   [k] = client_al [j];
                    int_alu_bl   [k] = client_bl [j];
                    int_alu_cl   [k] = client_cl [j];
                    client_pl    [j] = int_alu_pl[k];
                    int_alu_ar   [k] = client_ar [j];
                    int_alu_br   [k] = client_br [j];
                    int_alu_cr   [k] = client_cr [j];
                    client_pr    [j] = int_alu_pr[k];
                end
            end
        end
    end


    alu_nic_mul #(
        .CLIENTS_N     (                   ),
        .ALUS_N        (                   ),
        .ALUS_W        (                   )
    ) alu_nic_mul_inst (
        .clk           (                   ),
        .reset         (                   ),

        .client_strobe (                   ),
        .client_cycle  (                   ),
        .client_ack    (                   ),
        .client_stall  (                   ),
        //.client_err  (                   ), // TBI
        .client_mode   (                   ),
        .client_op     (                   ),
        .client_al     (                   ),
        .client_bl     (                   ),
        .client_cl     (                   ),
        .client_pl     (                   ),
        .client_ar     (                   ),
        .client_br     (                   ),
        .client_cr     (                   ),
        .client_pr     (                   ),
        .client_req    (                   ),
        .client_gnt    (                   ),

        .alu_strobe    (                   ),
        .alu_cycle     (                   ),
        .alu_ack       (                   ),
        .alu_stall     (                   ),
        //.alu_err     (                   ), // TBI
        .alu_mode      (                   ),
        .alu_op        (                   ),
        .alu_al        (                   ),
        .alu_bl        (                   ),
        .alu_cl        (                   ),
        .alu_pl        (                   ),
        .alu_ar        (                   ),
        .alu_br        (                   ),
        .alu_cr        (                   ),
        .alu_pr        (                   )
    );

    generate for (i = 0; i < DSPS_N; i=i+1) begin : int_alu_inst
        alu_top alu_inst (
            .clk        (clk                ),
            .reset      (reset              ),
            .alu_strobe (alu_strobe         ),
            .alu_cycle  (alu_cycle          ),
            .alu_ack    (alu_ack            ),
            .alu_stall  (alu_stall          ),
            //.alu_err  (alu_err            ), // TBI
            .alu_mode   (alu_mode           ),
            .alu_op     (int_alu_op[i]      ),
            .alu_al     (int_alu_al[i]      ),
            .alu_bl     (int_alu_bl[i]      ),
            .alu_cl     (int_alu_cl[i]      ),
            .alu_pl     (int_alu_pl[i]      ),
            .alu_ar     (int_alu_ar[i]      ),
            .alu_br     (int_alu_br[i]      ),
            .alu_cr     (int_alu_cr[i]      ),
            .alu_pr     (int_alu_pr[i]      )
        );
    end endgenerate
endmodule
