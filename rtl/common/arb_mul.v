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
            first_one_bit = 32'h0;
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

    integer i;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i=0; i<GNTS_N; i=i+1) begin
                is_active[i] <= 'h0;
                gnt[i]       <= 'h0;
            end
            for (i=0; i<PORTS_N; i=i+1) begin
                gnt_id[i] <= 'h0;
            end
        end else begin
            for (i=0; i<GNTS_N; i=i+1) begin : arb_impl_body
                reg               is_acitive_new;
                reg [PORTS_N-1:0] gnt_new;
                reg [PORTS_N-1:0] req_next_stage;

                is_acitive_new = is_active[i];
                gnt_new        = gnt[i];
                req_next_stage = (i==0) ? req_in : req[i];

                if (is_acitive_new && (~req[i] & req_prev & gnt[i])) begin
                    // req deasserted
                    is_acitive_new  = 1'b0;
                    gnt_new         = 'h0;
                    req_next_stage  = req[i];
                end

                if (!is_acitive_new && (req[i] & ~req_prev)) begin
                    // req asserted
                    is_acitive_new  = 1'b1;
                    gnt_new         = first_one_bit(req[i] & ~req_prev);
                    gnt_id[first_one_pos(req[i] & ~req_prev)] <= i;
                    req_next_stage  = req[i] & ~gnt_new;
                end

                req[i+1]      = req_next_stage; 
                is_active[i] <= is_acitive_new;
                gnt[i]       <= gnt_new;
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
