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
    localparam GNTS_N  = 4;
    localparam GNTS_W  = 2;

    localparam IDLE_DLY_MAX = 300;
    localparam GNT_LEN_MAX  = 100;

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


    genvar i;
    generate for (i=0; i<PORTS_N; i=i+1) begin : client_inst_loop
        initial begin : client_inst
            integer idle_dly;
            integer gnt_len;

            forever begin
                while (reset !== 1'b0) @(posedge clk);

                idle_dly = $random() % IDLE_DLY_MAX;
                gnt_len  = $random() % GNT_LEN_MAX;

                req[i] <= 1'b0;
                repeat (idle_dly       ) @(posedge clk);
                req[i] <= 1'b1;
                @(posedge clk);
                while  (gnt[i] === 1'b0) @(posedge clk);
                repeat (gnt_len        ) @(posedge clk);
            end
        end
    end endgenerate


    function integer ones_count;
        input [PORTS_N-1:0] val;
        integer i;
        begin
            ones_count = 0;
            for (i=0; i<PORTS_N; i=i+1) begin
                if (val[i]) ones_count = ones_count+1;
            end
        end
    endfunction


    initial begin
        reset  <= 1;
        repeat (10) @(posedge clk);
        reset  <= 0;

        forever begin : dut_checks
            integer j, k;

            @(posedge clk);
            if (ones_count(gnt) > GNTS_N) begin
                $display("Error: Number of grants is greater than GNTS_N: 0x%0h", gnt);
            end

            for (j = 0; j < PORTS_N-1; j=j+1) begin
                for (k = j+1; k < PORTS_N; k=k+1) begin
                    if (gnt[j] && gnt[k] && gnt_id[GNTS_W*j+:GNTS_W] === gnt_id[GNTS_W*k+:GNTS_W]) begin
                        $display("Error: Duplication of the gnt_id: gnt:0x%0h gnt_id:0x%0h gnt:0x%0h gnt_id:0x%0h",
                            j, gnt_id[GNTS_W*j+:GNTS_W], k, gnt_id[GNTS_W*k+:GNTS_W]);
                    end
                end
            end
        end
    end
endmodule
