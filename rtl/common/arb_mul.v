// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: arb_mul.v
// Description: Simple round-robin arbiter for multiple outputs
// -----------------------------------------------------------------------------

module arb_mul
(
    input                           reset       ,
    input                           clk         ,
    input      [PORTS_N-1:0]        req_in      ,
    output reg [PORTS_N-1:0]        gnt_out     ,
    output reg [PORTS_N*GNTS_W-1:0] gnt_id_out  
);

    parameter  PORTS_N = 4;
    parameter  GNTS_N  = 2;
    parameter  GNTS_W  = 1;


    function [PORTS_N-1:0] first_one_pos;
        input [PORTS_N-1:0] val;
        integer i;
        begin
            first_one_pos = PORTS_N;
            for (i = 0; i < PORTS_N; i = i+1) begin
                if (val[i] && first_one_pos == PORTS_N) begin
                    first_one_pos = i;
                end
            end
        end
    endfunction

    function [PORTS_N-1:0] first_one_bit;
        input [PORTS_N-1:0] val;
        integer j;
        begin
            first_one_bit = 'h0;
            for (j = 0; j < PORTS_N; j = j+1) begin
                if (val[j] && first_one_bit == 0) begin
                    first_one_bit[j] = 1'b1;
                end
            end
        end
    endfunction


    reg  [PORTS_N-1:0] req_prev;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            req_prev <= 'h0;
        end else begin
            req_prev <= req_in;
        end
    end


    reg [PORTS_N-1:0] req      [0:GNTS_N-1];
    reg [PORTS_N-1:0] gnt      [0:GNTS_N-1];
    reg               is_active[0:GNTS_N-1];
    reg [GNTS_W-1:0]  gnt_id   [0:PORTS_N-1];


    reg               is_acitive_new[0:GNTS_N-1];
    reg [PORTS_N-1:0] gnt_new       [0:GNTS_N-1];

    genvar i;
    generate for (i=0; i<GNTS_N; i=i+1) begin : arb_logic_block
        always @(*) begin : arb_logic_always
            reg [PORTS_N-1:0] req_next_stage;
            is_acitive_new[i]      = is_active[i];
            gnt_new[i]             = gnt[i];

            if (i == 0) begin
                req[i]             = req_in;
            end

            req_next_stage         = ~gnt[i] &  req[i];

            if (is_acitive_new[i] && (~req[i] & req_prev & gnt[i])) begin
                is_acitive_new[i]  = 1'b0;
                gnt_new[i]         = 'h0;
                req_next_stage     = req[i];
            end

            if (!is_acitive_new[i] && req[i]) begin
                is_acitive_new[i]  = 1'b1;
                gnt_new[i]         = first_one_bit(req[i]);
                req_next_stage     = req[i] & ~first_one_bit(req[i]);
            end

            if (i != GNTS_N-1) begin
                req[i+1]           = req_next_stage; 
            end
        end
    end endgenerate

    integer ii;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (ii=0; ii<GNTS_N; ii=ii+1) begin
                is_active[ii] <= 'h0;
                gnt[ii]       <= 'h0;
            end
            for (ii=0; ii<PORTS_N; ii=ii+1) begin
                gnt_id[ii]    <= 'h0;
            end
        end else begin : arb_impl_body
            for (ii=0; ii<GNTS_N; ii=ii+1) begin

                // TODO set using mask
                gnt_id[first_one_pos(req[ii] & ~req_prev)] <= ii;

                is_active[ii] <= is_acitive_new[ii];
                gnt[ii]       <= gnt_new[ii];
            end
        end
    end

    integer j;
    always @(*) begin
        gnt_out = 'h0;
        for (j = 0; j < GNTS_N; j = j+1) begin
            gnt_out = gnt_out | gnt[j];
        end
    end

    integer k;
    always @(*) begin
        for (k = 0; k < PORTS_N; k = k+1) begin
            gnt_id_out[GNTS_W*k +: GNTS_W] = gnt_id[k];
        end
    end

    /*
    // Tokens
    wire               req;
    wire               req_token_rdy;
    wire [GNTS_W-1:0]  req_token;
    wire               ret;
    wire [GNTS_W-1:0]  ret_token;

    wire req_token = (masked_req & rr_cnt) ? 1'b1 : 1'b0;

    token_manager #(
        .TOKENS        (GNTS_N              ),
        .TOKEN_W       (GNTS_W              )
    )
    token_manager_inst
    (
        .reset         (reset               ),
        .clk           (clk                 ),
        .req           (req                 ),
        .req_token_rdy (req_token_rdy       ),
        .req_token     (req_token           ),
        .ret           (ret                 ),
        .ret_token     (ret_token           )
    );
    */

endmodule
