// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: top_traffic_gen.v
// Description: Top level for testing SDRAM with traffic generator on FPGA
// -----------------------------------------------------------------------------

module top_traffic_gen(
    input            CLK_50M          ,
    input            BTN_RST          ,
    output [1:0]     LED              ,

    // INTERFACE TO SDRAM
    output           SDRAM_CLK        ,
    output           SDRAM_CKE        ,
    output           SDRAM_NCS        ,
    output           SDRAM_NCAS       ,
    output           SDRAM_NRAS       ,
    output           SDRAM_NWE        ,
    output           SDRAM_DQML       ,
    output           SDRAM_DQMH       ,
    output [12:0]    SDRAM_A          ,
    output [ 1:0]    SDRAM_BA         ,
    inout  [15:0]    SDRAM_DQ
);

    parameter AW_CSR   = 16;
    parameter AW_SDRAM = 32;

    wire clk;
    wire clk_valid;
    wire reset_n = clk_valid & BTN_RST;
    wire reset   = ~reset_n;

    ip_clk_gen_100M  clk_gen
    (
        .clk_in_50M   (CLK_50M          ), 
        .clk_out_100M (clk              ), 
        .CLK_VALID    (clk_valid        )
    );

    assign LED[0] = data_mismatch;
    assign LED[1] = wbs_sdram_address[24];

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

    wire data_mismatch;

    wbm_traffic_gen wbm_traffic_gen_inst
    (
        .clk                 (clk                         ),
        .reset               (reset                       ),
                                                       
        //.enable_traffic_gen(enable_traffic_gen          ),
        .enable_traffic_gen  (1'b1                        ),
        .data_mismatch       (data_mismatch               ),

        // WISHBONE SLAVE INTERFACE FOR SDRAM ACCESS
        .wbm_sdram_address   (wbs_sdram_address           ),
        .wbm_sdram_writedata (wbs_sdram_writedata         ),
        .wbm_sdram_readdata  (wbs_sdram_readdata          ),
        .wbm_sdram_strobe    (wbs_sdram_strobe            ),
        .wbm_sdram_cycle     (wbs_sdram_cycle             ),
        .wbm_sdram_write     (wbs_sdram_write             ),
        .wbm_sdram_ack       (wbs_sdram_ack               ),
        .wbm_sdram_stall     (wbs_sdram_stall             )
    );


    sdram_top sdram_top_inst (
        .clk                 (clk                         ),
        .reset               (reset                       ),
                                                          
        // WISHBONE SLAVE INTERFACE FOR CSR               
        .wbs_csr_address     (16'h0                       ),
        .wbs_csr_writedata   (32'h0                       ),
        .wbs_csr_readdata    (                            ),
        .wbs_csr_strobe      (1'b0                        ),
        .wbs_csr_cycle       (1'b0                        ),
        .wbs_csr_write       (1'b0                        ),
        .wbs_csr_ack         (                            ),
                                                          
        // WISHBONE SLAVE INTERFACE FOR SDRAM ACCESS
        .wbs_sdram_address   (wbs_sdram_address           ),
        .wbs_sdram_writedata (wbs_sdram_writedata         ),
        .wbs_sdram_readdata  (wbs_sdram_readdata          ),
        .wbs_sdram_strobe    (wbs_sdram_strobe            ),
        .wbs_sdram_cycle     (wbs_sdram_cycle             ),
        .wbs_sdram_write     (wbs_sdram_write             ),
        .wbs_sdram_ack       (wbs_sdram_ack               ),
        .wbs_sdram_stall     (wbs_sdram_stall             ),
        //.wbs_sdram_err     (wbs_sdram_err               ), // TBI

        // INTERFACE TO SDRAM
        .sdram_if_clk        (SDRAM_CLK                   ),
        .sdram_if_cke        (SDRAM_CKE                   ),
        .sdram_if_ncs        (SDRAM_NCS                   ),
        .sdram_if_ncas       (SDRAM_NCAS                  ),
        .sdram_if_nras       (SDRAM_NRAS                  ),
        .sdram_if_nwe        (SDRAM_NWE                   ),
        .sdram_if_dqml       (SDRAM_DQML                  ),
        .sdram_if_dqmh       (SDRAM_DQMH                  ),
        .sdram_if_a          (SDRAM_A                     ),
        .sdram_if_ba         (SDRAM_BA                    ),
        .sdram_if_dq         (SDRAM_DQ                    )
    );

endmodule
