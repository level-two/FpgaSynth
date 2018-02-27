// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: tb_sdram_tgen.v
// Description: Test bench for SDRAM block
// -----------------------------------------------------------------------------

`timescale 1ns/100ps

module tb_top;
    localparam TIMESTEP = 1e-9;
    localparam CLK_FREQ = 50_000_000;
    real CLK_PERIOD     = (1 / (TIMESTEP * CLK_FREQ));

    reg        CLK_50M;
    reg  [0:0] PB;
    wire [1:0] LED;

    // INTERFACE TO SDRAM
    wire         sdram_if_clk ;
    wire         sdram_if_cke ;
    wire         sdram_if_ncs ;
    wire         sdram_if_ncas;
    wire         sdram_if_nras;
    wire         sdram_if_nwe ;
    wire         sdram_if_dqml;
    wire         sdram_if_dqmh;
    wire [12:0]  sdram_if_a   ;
    wire [ 1:0]  sdram_if_ba  ;
    tri  [15:0]  sdram_if_dq  ;

    top_traffic_gen top_traffic_gen_inst (
        .CLK_50M          (CLK_50M               ),
        .PB               (PB                    ),
        .LED              (LED                   ),
        .SDRAM_CLK        (sdram_if_clk          ),
        .SDRAM_CKE        (sdram_if_cke          ),
        .SDRAM_NCS        (sdram_if_ncs          ),
        .SDRAM_NCAS       (sdram_if_ncas         ),
        .SDRAM_NRAS       (sdram_if_nras         ),
        .SDRAM_NWE        (sdram_if_nwe          ),
        .SDRAM_DQML       (sdram_if_dqml         ),
        .SDRAM_DQMH       (sdram_if_dqmh         ),
        .SDRAM_A          (sdram_if_a            ),
        .SDRAM_BA         (sdram_if_ba           ),
        .SDRAM_DQ         (sdram_if_dq           )
    );

    mt48lc16m16a2 sdram_model_inst (
        .Dq         (sdram_if_dq               ),
        .Addr       (sdram_if_a                ),
        .Ba         (sdram_if_ba               ),
        .Clk        (sdram_if_clk              ),
        .Cke        (sdram_if_cke              ),
        .Cs_n       (sdram_if_ncs              ),
        .Ras_n      (sdram_if_nras             ),
        .Cas_n      (sdram_if_ncas             ),
        .We_n       (sdram_if_nwe              ),
        .Dqm        ({sdram_if_dqmh, sdram_if_dqml})
    );

    initial $timeformat(-9, 0, " ns", 0);

    initial begin
        CLK_50M = 0;
        PB      = 1;
    end

    always begin
        #(CLK_PERIOD/2) CLK_50M = ~CLK_50M;
    end

endmodule
