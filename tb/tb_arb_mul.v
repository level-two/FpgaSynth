// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: tb_arb_mul.v
// Description: Testbench for the arbiter with multiple grants
// -----------------------------------------------------------------------------

`timescale 1ns/100ps

module tb_arb_mul();
    localparam TIMESTEP     = 1e-9;

    localparam A_CLK_FREQ   = 100_000_000;
    real       A_CLK_PERIOD = (1 / (TIMESTEP * A_CLK_FREQ));

    localparam PORTS_N = 10;
    localparam GNTS_N  = 2;
    localparam GNTS_W  = 2;

    reg        clk;
    reg        reset;

    initial begin
        clk <= 0;
    end

    always begin
        #(A_CLK_PERIOD/2);
        clk <= ~clk;
    end

    reg  [PORTS_N-1:0] req;
    wire [PORTS_N-1:0] gnt;
    wire [PORTS_N*GNTS_W-1:0] gnt_id;

    arb_mul #(
        .PORTS_N     (PORTS_N        ),
        .GNTS_N      (GNTS_N         ),
        .GNTS_W      (GNTS_W         )
    ) dut (
        .reset       (reset          ),
        .clk         (clk            ),
        .req         (req            ),
        .gnt         (gnt            ),
        .gnt_id      (gnt_id         )
    );


    initial begin
        reset  <= 1;
        req    <= 'h0;

        repeat (10) @(posedge clk);
        reset  <= 0;
        repeat (10) @(posedge clk);

        req    <= 'h0;

        repeat (PORTS_N) begin
            req <= {req, 1'b1};
            repeat (10) @(posedge clk);
        end

        repeat (PORTS_N) begin
            req <= {req, 1'b0};
            repeat (10) @(posedge clk);
        end
    end
endmodule
