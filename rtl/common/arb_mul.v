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
    input      [PORTS_N-1:0]        req         ,
    output reg [PORTS_N-1:0]        gnt         ,
    output     [PORTS_N*GNTS_W-1:0] gnt_id
);

    parameter  PORTS_N = 4;
    parameter  GNTS_N  = 2;
    parameter  GNTS_W  = clogb2(GNTS_N);


    function integer clogb2;
        input [31:0] value;
        begin
            value = value - 1;
            for (clogb2 = 0; value > 0; clogb2 = clogb2 + 1) begin
                value = value >> 1;
            end
        end
    endfunction

    function integer first_one_bit_pos;
        input [PORTS_N-1:0] value;
        integer i;
        begin
            first_one_bit_pos = PORTS_N;
            for (i=0; i<PORTS_N; i=i+1) begin
                if (first_one_bit_pos == PORTS_N && value[i]) begin
                    first_one_bit_pos = i;
                end
            end
        end
    endfunction


    // Rel fifo
    wire               rel_fifo_push;
    wire               rel_fifo_pop;
    wire [PORTS_N*GNTS_W+PORTS_N-1:0] rel_fifo_data_in;
    wire [PORTS_N*GNTS_W+PORTS_N-1:0] rel_fifo_data_out;
    wire               rel_fifo_empty;
    wire               rel_fifo_full;

    syn_fifo #(
        .DATA_W     (PORTS_N*GNTS_W+PORTS_N),
        .ADDR_W     (                GNTS_W),
        .FIFO_DEPTH (                GNTS_N)
    ) rel_fifo (                           
        .clk        (clk                   ),
        .rst        (reset                 ),
        .wr         (rel_fifo_push         ),
        .rd         (rel_fifo_pop          ),
        .data_in    (rel_fifo_data_in      ),
        .data_out   (rel_fifo_data_out     ),
        .empty      (rel_fifo_empty        ),
        .full       (rel_fifo_full         )
    );    


    // Token manager
    wire              token_mgr_req;
    wire              token_mgr_req_token_rdy;
    wire [GNTS_W-1:0] token_mgr_req_token;
    wire              token_mgr_rel;
    wire [GNTS_W-1:0] token_mgr_rel_token;

    token_manager #(
        .TOKENS        (GNTS_N                     ),
        .TOKEN_W       (GNTS_W                     )
    ) token_manager_inst (
        .reset         (reset                      ),
        .clk           (clk                        ),
        .req           (token_mgr_req              ),
        .req_token_rdy (token_mgr_req_token_rdy    ),
        .req_token     (token_mgr_req_token        ),
        .ret           (token_mgr_rel              ),
        .ret_token     (token_mgr_rel_token        )
    );


    reg [GNTS_W-1:0] gnt_id_val[0:PORTS_N-1];
    genvar i;
    generate for(i=0; i<PORTS_N; i=i+1) begin : gnt_id_assign
        assign gnt_id[GNTS_W*i+:GNTS_W] = gnt_id_val[i];
    end endgenerate


    reg  [PORTS_N-1:0] prev_req;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            prev_req <= 'h0;
        end else begin
            prev_req <= req;
        end
    end


    wire [PORTS_N-1:0] req_masked = req & ~gnt;
    wire [PORTS_N-1:0] rel_bits   = ~req & prev_req;
    assign token_mgr_req          = |req_masked;
    assign rel_fifo_push          = |rel_bits;
    assign rel_fifo_data_in       = {gnt_id, rel_bits};

    always @(posedge clk or posedge reset) begin
        if (reset) begin : gnt_reset
            integer j;
            for (j=0; j<PORTS_N; j=j+1) begin
                gnt_id_val[j] <= {GNTS_W{1'b0}};
            end
            gnt <= {PORTS_N{1'b0}};
        end else if (token_mgr_req_token_rdy) begin
            gnt_id_val[first_one_bit_pos(req_masked)] <= token_mgr_req_token;

            gnt <= (gnt | ('h1 << first_one_bit_pos(req_masked))) & ~rel_bits;

        end else begin
            gnt <= gnt & ~rel_bits;
        end
    end


    wire [GNTS_W-1:0] rel_gnt_id[0:PORTS_N-1];
    generate for(i=0; i<PORTS_N; i=i+1) begin : rel_gnt_id_assign
        assign rel_gnt_id[i] = rel_fifo_data_out[GNTS_W*i+PORTS_N+:GNTS_W];
    end endgenerate


    reg  [PORTS_N-1:0] rel_done;
    wire [PORTS_N-1:0] rel_masked = rel_fifo_data_out[PORTS_N-1:0] & ~rel_done;
    assign rel_fifo_pop           = !rel_fifo_empty && !rel_masked;
    assign token_mgr_rel          = !rel_fifo_empty &&  rel_masked;
    assign token_mgr_rel_token    =
        rel_fifo_empty ? {GNTS_W{1'b0}} :
        rel_gnt_id[first_one_bit_pos(rel_masked)];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rel_done <= {PORTS_N{1'b0}};
        end else if (rel_fifo_pop) begin
            rel_done <= {PORTS_N{1'b0}};
        end else if (!rel_fifo_empty) begin
            rel_done <= rel_done | ('h1 << first_one_bit_pos(rel_masked));
        end
    end
endmodule
