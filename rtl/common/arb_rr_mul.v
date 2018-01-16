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

    input  [PORTS_N-1:0] req,
    output [GNTS_N*PORTS_N-1:0] gnt_matrix
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


    reg  [PORTS_N-1:0] grants;
    wire masked_req = req & ~grants;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rr_cnt <= 'h1;
        end
        else begin
            if (masked_req && !(masked_req & rr_cnt)) begin
                rr_cnt <= {rr_cnt[PORTS_N-2:0], rr_cnt[PORTS_N-1]};
            end
        end
    end


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
endmodule
