// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: tb_sdram_tgen.v
// Description: Test bench for SDRAM block
// -----------------------------------------------------------------------------

`timescale 1ns/10ps

module tb_sdram_tgen();
    parameter AW_CSR   = 16;
    parameter AW_SDRAM = 32;

    reg                       reset               ;
    reg                       clk                 ;

    // WISHBONE SLAVE INTERFACE FOR SDRAM ACCESS
    wire [AW_SDRAM-1:0]       wbs_sdram_address   ;
    wire [15:0]               wbs_sdram_writedata ;
    wire [15:0]               wbs_sdram_readdata  ;
    wire                      wbs_sdram_strobe    ;
    wire                      wbs_sdram_cycle     ;
    wire                      wbs_sdram_write     ;
    wire                      wbs_sdram_ack       ;
    wire                      wbs_sdram_stall     ;
    //wire                    wbs_sdram_err       ; // TBI

    // INTERFACE TO SDRAM
    wire                      sdram_if_clk        ;
    wire                      sdram_if_cke        ;
    wire                      sdram_if_ncs        ;
    wire                      sdram_if_ncas       ;
    wire                      sdram_if_nras       ;
    wire                      sdram_if_nwe        ;
    wire                      sdram_if_dqml       ;
    wire                      sdram_if_dqmh       ;
    wire [12:0]               sdram_if_a          ;
    wire [ 1:0]               sdram_if_ba         ;
    tri  [15:0]               sdram_if_dq         ;


    reg  enable_traffic_gen;
    wire data_mismatch;

    wbm_traffic_gen wbm_traffic_gen_inst
    (
        .clk                 (clk                   ),
        .reset               (reset                 ),

        //.enable_traffic_gen(enable_traffic_gen    ),
        .enable_traffic_gen  (1'b1                  ),
        .data_mismatch       (data_mismatch         ),

        // WISHBONE SLAVE INTERFACE FOR SDRAM ACCESS
        .wbm_sdram_address   (wbs_sdram_address     ),
        .wbm_sdram_writedata (wbs_sdram_writedata   ),
        .wbm_sdram_readdata  (wbs_sdram_readdata    ),
        .wbm_sdram_strobe    (wbs_sdram_strobe      ),
        .wbm_sdram_cycle     (wbs_sdram_cycle       ),
        .wbm_sdram_write     (wbs_sdram_write       ),
        .wbm_sdram_ack       (wbs_sdram_ack         ),
        .wbm_sdram_stall     (wbs_sdram_stall       )
    );

    sdram_top dut (
        .clk                 (clk                   ),
        .reset               (reset                 ),

        // WISHBONE SLAVE INTERFACE FOR CSR
        .wbs_csr_address     ('h0                   ),
        .wbs_csr_writedata   ('h0                   ),
        .wbs_csr_readdata    (                      ),
        .wbs_csr_strobe      (1'b0                  ),
        .wbs_csr_cycle       (1'b0                  ),
        .wbs_csr_write       (1'b0                  ),
        .wbs_csr_ack         (                      ),

        // WISHBONE SLAVE INTERFACE FOR SDRAM ACCESS
        .wbs_sdram_address   (wbs_sdram_address     ),
        .wbs_sdram_writedata (wbs_sdram_writedata   ),
        .wbs_sdram_readdata  (wbs_sdram_readdata    ),
        .wbs_sdram_strobe    (wbs_sdram_strobe      ),
        .wbs_sdram_cycle     (wbs_sdram_cycle       ),
        .wbs_sdram_write     (wbs_sdram_write       ),
        .wbs_sdram_ack       (wbs_sdram_ack         ),
        .wbs_sdram_stall     (wbs_sdram_stall       ),
        //.wbs_sdram_err     (wbs_sdram_err         ), // TBI

        // INTERFACE TO SDRAM
        .sdram_if_clk        (sdram_if_clk          ),
        .sdram_if_cke        (sdram_if_cke          ),
        .sdram_if_ncs        (sdram_if_ncs          ),
        .sdram_if_ncas       (sdram_if_ncas         ),
        .sdram_if_nras       (sdram_if_nras         ),
        .sdram_if_nwe        (sdram_if_nwe          ),
        .sdram_if_dqml       (sdram_if_dqml         ),
        .sdram_if_dqmh       (sdram_if_dqmh         ),
        .sdram_if_a          (sdram_if_a            ),
        .sdram_if_ba         (sdram_if_ba           ),
        .sdram_if_dq         (sdram_if_dq           )
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
                                              
    always begin                              
        #5; // 5ns                          
        clk <= ~clk;
    end

    initial begin
        clk   <= 0;
        reset <= 1;
        repeat (100) @(posedge clk);
        reset <= 0;
    end
endmodule
