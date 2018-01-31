// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: token_manager.v
// Description: Token manager
//              req: get token
//              ret: return previously retained token
// -----------------------------------------------------------------------------

module token_manager (
        input                    reset          ,
        input                    clk            ,
        input                    req            ,
        output                   req_token_rdy  ,
        output     [TOKEN_W-1:0] req_token      ,
        input                    ret            ,
        input      [TOKEN_W-1:0] ret_token      
    );

    parameter TOKENS  = 16;
    parameter TOKEN_W = 4;

    // init mode
    reg               init_mode;
    reg [TOKEN_W-1:0] init_token_cnt;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            init_mode      <= 1'b1;
            init_token_cnt <= 'h0;
        end else if (init_mode && req) begin
            init_mode      <= (init_token_cnt == TOKENS-1) ? 1'b0 : 1'b1;
            init_token_cnt <= init_token_cnt + 1;
        end 
    end

    wire fifo_push;
    wire fifo_pop;
    wire [TOKEN_W-1:0] fifo_in;
    wire [TOKEN_W-1:0] fifo_out;
    wire fifo_empty;
    wire fifo_full;

    /*
    assign fifo_pop      = ~init_mode & ~fifo_empty & req;
    assign req_token_rdy = init_mode  | ~fifo_empty;
    assign req_token     = init_mode  ? init_token_cnt : fifo_out;
    */

    assign fifo_push     = ret;
    assign fifo_in       = ret_token;

    assign fifo_pop      = init_mode  ? 1'b0 :
                           fifo_empty ? 1'b0 :
                                        req;
    assign req_token     = init_mode  ? init_token_cnt :
                                        fifo_out;
    assign req_token_rdy = init_mode  ? 1'b1  :
                           fifo_empty ? 1'b0  : 
                                        1'b1;
    syn_fifo #(
        .DATA_W     (TOKEN_W            ),
        .ADDR_W     (TOKEN_W            ),
        .FIFO_DEPTH (TOKENS             )
    ) buf_fifo (
        .clk        (clk                ),
        .rst        (reset              ),
        .wr         (fifo_push          ),
        .rd         (fifo_pop           ),
        .data_in    (fifo_in            ),
        .data_out   (fifo_out           ),
        .empty      (fifo_empty         ),
        .full       (fifo_full          )      
    );
endmodule
