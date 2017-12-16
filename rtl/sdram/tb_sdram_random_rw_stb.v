// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: tb_sdram_top.v
// Description: Test bench for SDRAM block
// -----------------------------------------------------------------------------

`timescale 1ns/10ps

module tb_sdram_random_rw_stb();
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
        .wbs_sdram_stall     (wbs_sdram_stall       ),

        //.wbs_sdram_err     (wbs_sdram_err         ), // TBI

        // INTERFACE TO SDRAM
        .sdram_if_clk           (sdram_if_clk             ),
        .sdram_if_cke           (sdram_if_cke             ),
        .sdram_if_ncs           (sdram_if_ncs             ),
        .sdram_if_ncas          (sdram_if_ncas            ),
        .sdram_if_nras          (sdram_if_nras            ),
        .sdram_if_nwe           (sdram_if_nwe             ),
        .sdram_if_dqml          (sdram_if_dqml            ),
        .sdram_if_dqmh          (sdram_if_dqmh            ),
        .sdram_if_a             (sdram_if_a               ),
        .sdram_if_ba            (sdram_if_ba              ),
        .sdram_if_dq            (sdram_if_dq              )
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

    initial begin
        wbs_csr_address   <= 0;
        wbs_csr_writedata <= 0;
        wbs_csr_strobe    <= 0;
        wbs_csr_cycle     <= 0;
        wbs_csr_write     <= 0;

        #110000; // 110 us

        @(posedge clk);

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

        @(posedge clk);

        wbs_csr_address   <= 'h0000;      // csr_ctrl register
        wbs_csr_writedata <= 'h0000_0000; // reset csr_ctrl_start
        wbs_csr_strobe    <= 1'b1;
        wbs_csr_cycle     <= 1'b1;
        wbs_csr_write     <= 1'b1;
        
        while (wbs_csr_ack == 1'b0) @(posedge clk);

        wbs_csr_address   <= 0;
        wbs_csr_writedata <= 0;
        wbs_csr_strobe    <= 0;
        wbs_csr_cycle     <= 0;
        wbs_csr_write     <= 0;
    end

    localparam NUM_OPS = 1000;

    integer trans_len;
    integer addr;

    initial begin
        wbs_sdram_cycle     <= 0;
        wbs_sdram_strobe    <= 0;
        wbs_sdram_address   <= 0;
        wbs_sdram_write     <= 0;
        wbs_sdram_writedata <= 0;

        trans_len  = 0;
        addr       = 0;

        #150000; // 150 us

        while (addr < 'h1000) begin
            @(posedge clk);
            wbs_sdram_cycle     <= 1;
            if (wbs_sdram_stall) begin
                // do nothing
            end
            else begin
                wbs_sdram_strobe    <= 1;
                wbs_sdram_address   <= addr;
                wbs_sdram_write     <= 1;
                wbs_sdram_writedata <= addr[15:0];
                addr = addr + 1;
            end
        end
        @(posedge clk);
        wbs_sdram_cycle     <= 0;
        wbs_sdram_strobe    <= 0;
        wbs_sdram_address   <= 0;
        wbs_sdram_write     <= 0;

        repeat (100) begin
            trans_len = 32;
            send_trans();
            repeat (5) @(posedge clk);
        end
        wbs_sdram_cycle     <= 0;
        repeat (10) @(posedge clk);

        $finish();
    end


    integer requests_n;
    integer acks_n;

    task send_trans();
    begin
        requests_n = 0;
        acks_n     = 0;
        addr       = 0;
        while (requests_n < trans_len) begin
            @(posedge clk);
            wbs_sdram_cycle     <= 1;
            if (!wbs_sdram_stall) begin
                wbs_sdram_strobe    <= 1;
                wbs_sdram_address   <= 'h400 + $random() % 'h300;
                wbs_sdram_write     <= $random() % 2;
                wbs_sdram_writedata <= $random() % 2 ? 'hdead : 'hbeef;
                requests_n          = requests_n + 1;
            end
            if (wbs_sdram_ack) begin
                acks_n = acks_n + 1;
            end
        end

        while (acks_n < trans_len) begin
            @(posedge clk);
            if (!wbs_sdram_stall) begin
                wbs_sdram_strobe <= 0;
            end
            if (wbs_sdram_ack) begin
                acks_n = acks_n + 1;
            end
        end
        
        if ($random() % 4 == 0) begin
            wbs_sdram_cycle <= 0;
        end
    end
    endtask

endmodule
