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

    //output_gnt  - clear immediatelly when req is deasserted
    //virtual_gnt - clear only when token is released



    reg  [PORTS_N-1:0] prev_req;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            prev_req <= 'h0;
        end else begin
            prev_req <= req_in;
        end
    end

    wire [PORTS_N-1:0] req_bits =  req & ~prev_req;
    wire [PORTS_N-1:0] rel_bits = ~req &  prev_req;

    assign req_fifo_push    = |req_bits;
    assign rel_fifo_push    = |rel_bits;
    assign req_fifo_data_in =  req_bits;
    assign rel_fifo_data_in =  rel_bits;



    assign tm_req       = !req_fifo_empty &&  (req_fifo_data_out & ~gnt);
    assign req_fifo_pop = !req_fifo_empty && !(req_fifo_data_out & ~gnt);





    // Req fifo
    wire               req_fifo_push;
    wire               req_fifo_pop;
    wire [FIFO_DW-1:0] req_fifo_data_in;
    wire [FIFO_DW-1:0] req_fifo_data_out;
    wire               req_fifo_empty;
    wire               req_fifo_full;

    syn_fifo #(
        .DATA_W     (           FIFO_DW),
        .ADDR_W     (                 4),
        .FIFO_DEPTH (                16)
    ) req_fifo (
        .clk        (clk               ),
        .rst        (reset             ),
        .wr         (req_fifo_push     ),
        .rd         (req_fifo_pop      ),
        .data_in    (req_fifo_data_in  ),
        .data_out   (req_fifo_data_out ),
        .empty      (req_fifo_empty    ),
        .full       (req_fifo_full     )
    );

    // Rel fifo
    wire               rel_fifo_push;
    wire               rel_fifo_pop;
    wire [FIFO_DW-1:0] rel_fifo_data_in;
    wire [FIFO_DW-1:0] rel_fifo_data_out;
    wire               rel_fifo_empty;
    wire               rel_fifo_full;

    syn_fifo #(
        .DATA_W     (           FIFO_DW),
        .ADDR_W     (                 4),
        .FIFO_DEPTH (                16)
    ) rel_fifo (
        .clk        (clk               ),
        .rst        (reset             ),
        .wr         (rel_fifo_push     ),
        .rd         (rel_fifo_pop      ),
        .data_in    (rel_fifo_data_in  ),
        .data_out   (rel_fifo_data_out ),
        .empty      (rel_fifo_empty    ),
        .full       (rel_fifo_full     )
    );    


    // Token manager
    wire              tm_req;
    wire              tm_req_token_rdy;
    wire [GNTS_W-1:0] tm_req_token;
    wire              tm_ret;
    wire [GNTS_W-1:0] tm_ret_token;

    token_manager #(
        .TOKENS        (GNTS_N              ),
        .TOKEN_W       (GNTS_W              )
    ) token_manager_inst (
        .reset         (reset               ),
        .clk           (clk                 ),
        .req           (tm_req              ),
        .req_token_rdy (tm_req_token_rdy    ),
        .req_token     (tm_req_token        ),
        .ret           (tm_rel              ),
        .ret_token     (tm_rel_token        )
    );

endmodule
