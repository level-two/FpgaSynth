// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: tb_sdram_top.v
// Description: Test bench for SDRAM block
// -----------------------------------------------------------------------------

`timescale 100ps/1ps

module tb_sdram_top();
    parameter AW_CSR   = 16;
    parameter AW_SDRAM = 32;

    reg                       reset               ;
    reg                       clk                 ;

    reg  [AW_CSR-1:0]         wbs_csr_address     ;
    reg  [31:0]               wbs_csr_writedata   ;
    wire [31:0]               wbs_csr_readdata    ;
    reg                       wbs_csr_strobe      ;
    reg                       wbs_csr_cycle       ;
    reg                       wbs_csr_write       ;
    wire                      wbs_csr_ack         ;

    // WISHBONE SLAVE INTERFACE FOR SDRAM ACCESS
    reg  [AW_SDRAM-1:0]       wbs_sdram_address   ;
    reg  [15:0]               wbs_sdram_writedata ;
    wire [15:0]               wbs_sdram_readdata  ;
    reg                       wbs_sdram_strobe    ;
    reg                       wbs_sdram_cycle     ;
    reg                       wbs_sdram_write     ;
    wire                      wbs_sdram_ack       ;
    //wire                    wbs_sdram_err       ; // TBI

    // INTERFACE TO SDRAM
    wire                      sdram_clk           ;
    wire                      sdram_cke           ;
    wire                      sdram_ncs           ;
    wire                      sdram_ncas          ;
    wire                      sdram_nras          ;
    wire                      sdram_nwe           ;
    wire                      sdram_dqml          ;
    wire                      sdram_dqmh          ;
    wire [12:0]               sdram_a             ;
    wire [ 1:0]               sdram_ba            ;
    reg  [15:0]               sdram_dq            ;


    sdram_top dut (
        .clk                 (clk                   ),
        .reset               (reset                 ),

        // WISHBONE SLAVE INTERFACE FOR CSR
        .wbs_csr_address     (wbs_csr_address       ),
        .wbs_csr_writedata   (wbs_csr_writedata     ),
        .wbs_csr_readdata    (wbs_csr_readdata      ),
        .wbs_csr_strobe      (wbs_csr_strobe        ),
        .wbs_csr_cycle       (wbs_csr_cycle         ),
        .wbs_csr_write       (wbs_csr_write         ),
        .wbs_csr_ack         (wbs_csr_ack           ),

        // WISHBONE SLAVE INTERFACE FOR SDRAM ACCESS
        .wbs_sdram_address   (wbs_sdram_address     ),
        .wbs_sdram_writedata (wbs_sdram_writedata   ),
        .wbs_sdram_readdata  (wbs_sdram_readdata    ),
        .wbs_sdram_strobe    (wbs_sdram_strobe      ),
        .wbs_sdram_cycle     (wbs_sdram_cycle       ),
        .wbs_sdram_write     (wbs_sdram_write       ),
        .wbs_sdram_ack       (wbs_sdram_ack         ),
        //.wbs_sdram_err     (wbs_sdram_err         ), // TBI

        // INTERFACE TO SDRAM
        .sdram_clk           (sdram_clk             ),
        .sdram_cke           (sdram_cke             ),
        .sdram_ncs           (sdram_ncs             ),
        .sdram_ncas          (sdram_ncas            ),
        .sdram_nras          (sdram_nras            ),
        .sdram_nwe           (sdram_nwe             ),
        .sdram_dqml          (sdram_dqml            ),
        .sdram_dqmh          (sdram_dqmh            ),
        .sdram_a             (sdram_a               ),
        .sdram_ba            (sdram_ba              ),
        .sdram_dq            (sdram_dq              )
    );



    mt48lc16m16a2 sdram_model_inst (
        .Dq         (sdram_dq               ),
        .Addr       (sdram_a                ),
        .Ba         (sdram_ba               ),
        .Clk        (sdram_clk              ),
        .Cke        (sdram_cke              ),
        .Cs_n       (sdram_ncs              ),
        .Ras_n      (sdram_nras             ),
        .Cas_n      (sdram_ncas             ),
        .We_n       (sdram_nwe              ),
        .Dqm        ({sdram_dqmh, sdram_dqml})
    );                                        
                                              
                                              
                                              
                                              
                                              
    always begin                              
        #5; // 500ps                          
        clk <= ~clk;
    end


    initial begin
        clk   <= 0;
        reset <= 1;
        repeat (100) @(posedge clk);
        reset <= 0;
    end

    initial begin
        wbs_csr_address   <= 0;
        wbs_csr_writedata <= 0;
        wbs_csr_strobe    <= 0;
        wbs_csr_cycle     <= 0;
        wbs_csr_write     <= 0;

        repeat (1500000) @(posedge clk);

        wbs_csr_address   <= 'h0000;      // csr_ctrl register
        wbs_csr_writedata <= 'h0000_0001; // csr_ctrl_start
        wbs_csr_strobe    <= 1'b1;
        wbs_csr_cycle     <= 1'b1;
        wbs_csr_write     <= 1'b1;
        
        while (wbs_csr_ack == 1'b0) @(posedge clk);

        wbs_csr_address   <= 0;
        wbs_csr_writedata <= 0;
        wbs_csr_strobe    <= 0;
        wbs_csr_cycle     <= 0;
        wbs_csr_write     <= 0;


        repeat (1500000) @(posedge clk);
        $finish();
    end

    initial begin
        wbs_sdram_address   <= 0;
        wbs_sdram_writedata <= 0;
        wbs_sdram_strobe    <= 0;
        wbs_sdram_cycle     <= 0;
        wbs_sdram_write     <= 0;
    end

    initial begin
        sdram_dq <= 0;
    end
endmodule
