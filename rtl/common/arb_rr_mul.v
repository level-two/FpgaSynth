// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: arb_rr_mul.v
// Description: Simple round-robin arbiter for multiple outputs
// -----------------------------------------------------------------------------

module arb_rr_mul
(
    input reset,
    input clk,

    input  [PORTS_N-1:0] req_in,
    output [PORTS_N-1:0] gnt_out,
    output [PORTS_N*GNTS_W-1:0] gnt_id_out
);

    parameter  PORTS_N = 4;
    parameter  GNTS_N  = 2;
    localparam GNTS_W  = clogb2(GNTS_N);

    function integer clogb2;
        input [31:0] value;
        begin
            value = value - 1;
            for (clogb2 = 0; value > 0; clogb2 = clogb2 + 1) begin
                value = value >> 1;
            end
        end
    endfunction

    function bit[PORTS_N-1:0] first_one_pos;
        input bit[PORTS_N-1:0] val;
        integer i;
        begin
            first_one_pos = PORTS_N;
            for (i = 0; i < PORTS_N; i = i+1) begin
                if (val[i]) begin
                    first_one_pos = i;
                    break;
                end
            end
        end
    endfunction

    function bit[PORTS_N-1:0] first_one_bit;
        input bit[PORTS_N-1:0] val;
        integer i;
        begin
            first_one_bit = 32'h0;
            for (i = 0; i < PORTS_N; i = i+1) begin
                if (val[i]) begin
                    first_one_bit[i] = 1'b1;
                    break;
                end
            end
        end
    endfunction


    reg  [PORTS_N-1:0] req_prev;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            req_prev <= 1'b0;
        end else begin
            req_prev <= req;
        end
    end


    reg [PORTS_N-1:0] req      [0:GNTS_N-1];
    reg [PORTS_N-1:0] gnt      [0:GNTS_N-1];
    reg               is_active[0:GNTS_N-1];
    reg [GNTS_W-1:0]  gnt_id   [0:PORTS_N-1];

    genvar i;

    always @(posedge clk or posedge reset) begin
        generate for (i = 0; i < GNTS_N; i = i+1) begin : arb_impl
            if (reset) begin
                is_active[i] <= 'h0;
                gnt[i]       <= 'h0;
            end
            else begin
                reg               is_acitive_new = is_active[i];
                reg [PORTS_N-1:0] gnt_new        = gnt[i];
                reg [PORTS_N-1:0] req_next_stage;

                req_next_stage = (i==0) ? req_in : req[i];

                if (is_acitive_new && (~req[i] & req_prev[i] & gnt[i]) begin
                    // req deasserted
                    is_acitive_new  = 1'b0;
                    gnt_new         = 'h0;
                    req_next_stage  = req[i];
                end

                if (!is_acitive_new && (req[i] & ~req_prev[i]) begin
                    // req asserted
                    is_acitive_new  = 1'b1;
                    gnt_new         = first_one_bit(req[i] & ~req_prev[i]);
                    req_next_stage  = req[i] & ~gnt_new;
                    gnt_id[first_one_pos(gnt_new)] <= i;
                end

                req_i[i+1]    = req_next_stage; 
                is_active[i] <= is_acitive_new;
                gnt[i]       <= gnt_new;
            end
        end endgenerate
    end


    integer j;
    always @(*) begin
        gnt_out = 'h0;
        for (j = 0; j < GNTS_N; j = j+1) begin
            gnt_out = gnt_out | gnt[j];
        end
    end

    integer k;
    for (k = 0; k < PORTS_N; k = k+1) begin
        assign gnt_id_out[GNTS_W*(k+1)-1:GNTS_W*k] = gnt_id[k];
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
