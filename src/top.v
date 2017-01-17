// -----------------------------------------------------------------------------
// Copyright (C) 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: top.v
// Description: Top level module with external FPGA interface
// -----------------------------------------------------------------------------

module top (
    input            CLK_50M,
    input      [0:0] PB,      // UART rx
    input      [0:0] PMOD4,   // UART rx
    output     [0:0] PMOD3    // SPDIF out
);

    wire uart_rx;
    assign PMOD4[0] = uart_rx;

    wire spdif_out;
    assign PMOD3[0] = spdif_out;

    wire clk;
    wire reset_n = clk_valid & PB[0];

    clk_gen_100M clk_gen
    (
        .clk_in_50M(CLK_50M), 
        .clk_out_100M(clk), 
        .CLK_VALID(clk_valid)
    );



/*
    `include "globals.vh"

    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;
    parameter CLK_PER    = 20;

    wire reset_n;
    wire reset = !reset_n;
    
    wire clk;

    // Wishbone Master signals
    wire [ADDR_WIDTH-1:0] ctrl_wbm_address;
    wire [DATA_WIDTH-1:0] ctrl_wbm_writedata;
    wire [DATA_WIDTH-1:0] ctrl_wbm_readdata;
    wire                  ctrl_wbm_strobe;
    wire                  ctrl_wbm_cycle;
    wire                  ctrl_wbm_write;
    wire                  ctrl_wbm_ack;

    wire [ADDR_WIDTH-1:0] ldrv_wbm_address;
    wire [DATA_WIDTH-1:0] ldrv_wbm_writedata;
    wire [DATA_WIDTH-1:0] ldrv_wbm_readdata;
    wire                  ldrv_wbm_strobe;
    wire                  ldrv_wbm_cycle;
    wire                  ldrv_wbm_write;
    wire                  ldrv_wbm_ack;

    wire [ADDR_WIDTH-1:0] bupd_wbm_address;
    wire [DATA_WIDTH-1:0] bupd_wbm_writedata;
    wire [DATA_WIDTH-1:0] bupd_wbm_readdata;
    wire                  bupd_wbm_strobe;
    wire                  bupd_wbm_cycle;
    wire                  bupd_wbm_write;
    wire                  bupd_wbm_ack;

    wire [ADDR_WIDTH-1:0] imgd_wbm_address;
    wire [DATA_WIDTH-1:0] imgd_wbm_writedata;
    wire [DATA_WIDTH-1:0] imgd_wbm_readdata;
    wire                  imgd_wbm_strobe;
    wire                  imgd_wbm_cycle;
    wire                  imgd_wbm_write;
    wire                  imgd_wbm_ack;

    wire [ADDR_WIDTH-1:0] imgr_wbm_address;
    wire [DATA_WIDTH-1:0] imgr_wbm_writedata;
    wire [DATA_WIDTH-1:0] imgr_wbm_readdata;
    wire                  imgr_wbm_strobe;
    wire                  imgr_wbm_cycle;
    wire                  imgr_wbm_write;
    wire                  imgr_wbm_ack;


    // Wishbone Slave signals
    wire [ADDR_WIDTH-1:0] spi_wbs_address;
    wire [DATA_WIDTH-1:0] spi_wbs_writedata;
    wire [DATA_WIDTH-1:0] spi_wbs_readdata;
    wire                  spi_wbs_strobe;
    wire                  spi_wbs_cycle;
    wire                  spi_wbs_write;
    wire                  spi_wbs_ack;

    wire [ADDR_WIDTH-1:0] bmgr_wbs_address;
    wire [DATA_WIDTH-1:0] bmgr_wbs_writedata;
    wire [DATA_WIDTH-1:0] bmgr_wbs_readdata;
    wire                  bmgr_wbs_strobe;
    wire                  bmgr_wbs_cycle;
    wire                  bmgr_wbs_write;
    wire                  bmgr_wbs_ack;

    wire [ADDR_WIDTH-1:0] mem_wbs_address;
    wire [DATA_WIDTH-1:0] mem_wbs_writedata;
    wire [DATA_WIDTH-1:0] mem_wbs_readdata;
    wire                  mem_wbs_strobe;
    wire                  mem_wbs_cycle;
    wire                  mem_wbs_write;
    wire                  mem_wbs_ack;

    // Spi signals
    wire                  spi_done;

    // Spi image receiver signals
    wire [DATA_WIDTH-1:0] img_buf_id;
    wire                  img_rcvd;

    // Image display signals
    wire                  display_image;
    wire [DATA_WIDTH-1:0] display_image_buf_id;
    wire                  display_image_done;

    // Bufer updater signals
    //wire [DATA_WIDTH-1:0] update_buf_id;
    //wire                  update_buf;
    //wire                  buf_updated;

    // Led driver signals
    wire [DATA_WIDTH-1:0] led_tx_buf_id;
    wire                  led_tx;
    wire                  led_tx_done;
    wire                  led_data_out;

    assign PMOD4 = led_data_out;

    wb_nic #(ADDR_WIDTH, DATA_WIDTH) wb_nic
    (
        .reset(reset),
        .clk(clk),

        .ctrl_wbm_address(ctrl_wbm_address),
        .ctrl_wbm_writedata(ctrl_wbm_writedata),
        .ctrl_wbm_readdata(ctrl_wbm_readdata),
        .ctrl_wbm_strobe(ctrl_wbm_strobe),
        .ctrl_wbm_cycle(ctrl_wbm_cycle),
        .ctrl_wbm_write(ctrl_wbm_write),
        .ctrl_wbm_ack(ctrl_wbm_ack),

        
        .ldrv_wbm_address(ldrv_wbm_address),
        .ldrv_wbm_writedata(ldrv_wbm_writedata),
        .ldrv_wbm_readdata(ldrv_wbm_readdata),
        .ldrv_wbm_strobe(ldrv_wbm_strobe),
        .ldrv_wbm_cycle(ldrv_wbm_cycle),
        .ldrv_wbm_write(ldrv_wbm_write),
        .ldrv_wbm_ack(ldrv_wbm_ack),

        .bupd_wbm_address(bupd_wbm_address),
        .bupd_wbm_writedata(bupd_wbm_writedata),
        .bupd_wbm_readdata(bupd_wbm_readdata),
        .bupd_wbm_strobe(bupd_wbm_strobe),
        .bupd_wbm_cycle(bupd_wbm_cycle),
        .bupd_wbm_write(bupd_wbm_write),
        .bupd_wbm_ack(bupd_wbm_ack),

        .imgd_wbm_address(imgd_wbm_address),
        .imgd_wbm_writedata(imgd_wbm_writedata),
        .imgd_wbm_readdata(imgd_wbm_readdata),
        .imgd_wbm_strobe(imgd_wbm_strobe),
        .imgd_wbm_cycle(imgd_wbm_cycle),
        .imgd_wbm_write(imgd_wbm_write),
        .imgd_wbm_ack(imgd_wbm_ack),

        .imgr_wbm_address(imgr_wbm_address),
        .imgr_wbm_writedata(imgr_wbm_writedata),
        .imgr_wbm_readdata(imgr_wbm_readdata),
        .imgr_wbm_strobe(imgr_wbm_strobe),
        .imgr_wbm_cycle(imgr_wbm_cycle),
        .imgr_wbm_write(imgr_wbm_write),
        .imgr_wbm_ack(imgr_wbm_ack),

        
        .spi_wbs_address(spi_wbs_address),
        .spi_wbs_writedata(spi_wbs_writedata),
        .spi_wbs_readdata(spi_wbs_readdata),
        .spi_wbs_strobe(spi_wbs_strobe),
        .spi_wbs_cycle(spi_wbs_cycle),
        .spi_wbs_write(spi_wbs_write),
        .spi_wbs_ack(spi_wbs_ack),
        
        .bmgr_wbs_address(bmgr_wbs_address),
        .bmgr_wbs_writedata(bmgr_wbs_writedata),
        .bmgr_wbs_readdata(bmgr_wbs_readdata),
        .bmgr_wbs_strobe(bmgr_wbs_strobe),
        .bmgr_wbs_cycle(bmgr_wbs_cycle),
        .bmgr_wbs_write(bmgr_wbs_write),
        .bmgr_wbs_ack(bmgr_wbs_ack),

        .mem_wbs_address(mem_wbs_address),
        .mem_wbs_writedata(mem_wbs_writedata),
        .mem_wbs_readdata(mem_wbs_readdata),
        .mem_wbs_strobe(mem_wbs_strobe),
        .mem_wbs_cycle(mem_wbs_cycle),
        .mem_wbs_write(mem_wbs_write),
        .mem_wbs_ack(mem_wbs_ack)
    );


    // dut
    wb_spi #(ADDR_WIDTH, DATA_WIDTH) wb_spi
    (
        .reset(reset),
        .clk(clk),

        // Wishbone signals
        .wbs_address(spi_wbs_address),
        .wbs_writedata(spi_wbs_writedata),
        .wbs_readdata(spi_wbs_readdata),
        .wbs_strobe(spi_wbs_strobe),
        .wbs_cycle(spi_wbs_cycle),
        .wbs_write(spi_wbs_write),
        .wbs_ack(spi_wbs_ack),

        // Spi signals
        .mosi(SYS_SPI_MOSI),
        .ss(RP_SPI_CE0N), 
        .sclk(SYS_SPI_SCK),
        .miso(SYS_SPI_MISO),

        // Done signal
        .spi_done(spi_done)
    );


    spi_image_rcvr #(ADDR_WIDTH, DATA_WIDTH) spi_image_rcvr
    (
        .reset(reset),
        .clk(clk),

        .wbm_address(imgr_wbm_address),
        .wbm_writedata(imgr_wbm_writedata),
        .wbm_readdata(imgr_wbm_readdata),
        .wbm_strobe(imgr_wbm_strobe),
        .wbm_cycle(imgr_wbm_cycle),
        .wbm_write(imgr_wbm_write),
        .wbm_ack(imgr_wbm_ack),

        .spi_done(spi_done),

        // Signals from contorll logic
        .img_buf_id(img_buf_id),
        .img_rcvd(img_rcvd)
    );



    buf_manager #(ADDR_WIDTH, DATA_WIDTH, `NBUFS) buf_manager
    (
        .reset(reset),
        .clk(clk),

        // Wishbone signals
        .wbs_address(bmgr_wbs_address),
        .wbs_writedata(bmgr_wbs_writedata),
        .wbs_readdata(bmgr_wbs_readdata),
        .wbs_strobe(bmgr_wbs_strobe),
        .wbs_cycle(bmgr_wbs_cycle),
        .wbs_write(bmgr_wbs_write),
        .wbs_ack(bmgr_wbs_ack)
    );

    buf_updater_squares #(ADDR_WIDTH, DATA_WIDTH) buf_updater_squares
    (
        .reset(reset),
        .clk(clk),

        // Wishbone master signals
        .wbm_address(bupd_wbm_address),
        .wbm_writedata(bupd_wbm_writedata),
        .wbm_readdata(bupd_wbm_readdata),
        .wbm_strobe(bupd_wbm_strobe),
        .wbm_cycle(bupd_wbm_cycle),
        .wbm_write(bupd_wbm_write),
        .wbm_ack(bupd_wbm_ack),

        // control signals
        .buf_id(update_buf_id),
        .update_buf(update_buf),
        .buf_updated(buf_updated)
    );

    ctrl_logic #(ADDR_WIDTH, DATA_WIDTH) ctrl_logic
    (
        .reset(reset),
        .clk(clk),

        .wbm_address(ctrl_wbm_address),
        .wbm_writedata(ctrl_wbm_writedata),
        .wbm_readdata(ctrl_wbm_readdata),
        .wbm_strobe(ctrl_wbm_strobe),
        .wbm_cycle(ctrl_wbm_cycle),
        .wbm_write(ctrl_wbm_write),
        .wbm_ack(ctrl_wbm_ack),
        
        .update_buf_id(update_buf_id),
        .update_buf(update_buf),
        .buf_updated(buf_updated),

        .display_image(display_image),
        .image_buf_id(image_buf_id),
        .display_image_done(display_image_done)
    );

    ctrl_logic_img #(ADDR_WIDTH, DATA_WIDTH) ctrl_logic_img
    (
        .reset(reset),
        .clk(clk),

        .wbm_address(ctrl_wbm_address),
        .wbm_writedata(ctrl_wbm_writedata),
        .wbm_readdata(ctrl_wbm_readdata),
        .wbm_strobe(ctrl_wbm_strobe),
        .wbm_cycle(ctrl_wbm_cycle),
        .wbm_write(ctrl_wbm_write),
        .wbm_ack(ctrl_wbm_ack),
        
        .img_buf_id(img_buf_id),
        .img_rcvd(img_rcvd),

        .display_image(display_image),
        .display_image_buf_id(display_image_buf_id),
        .display_image_done(display_image_done)
    );


    mem #(ADDR_WIDTH, DATA_WIDTH) mem
    (
        .reset(reset),
        .clk(clk),

        // Wishbone signals
        .wbs_address(mem_wbs_address),
        .wbs_writedata(mem_wbs_writedata),
        .wbs_readdata(mem_wbs_readdata),
        .wbs_strobe(mem_wbs_strobe),
        .wbs_cycle(mem_wbs_cycle),
        .wbs_write(mem_wbs_write),
        .wbs_ack(mem_wbs_ack)
    );


    image_display #(ADDR_WIDTH, DATA_WIDTH) image_display
    (
        .reset(reset),
        .clk(clk),

        .wbm_address(imgd_wbm_address),
        .wbm_writedata(imgd_wbm_writedata),
        .wbm_readdata(imgd_wbm_readdata),
        .wbm_strobe(imgd_wbm_strobe),
        .wbm_cycle(imgd_wbm_cycle),
        .wbm_write(imgd_wbm_write),
        .wbm_ack(imgd_wbm_ack),

        .display_image(display_image),
        .display_image_buf_id(display_image_buf_id),
        .display_image_done(display_image_done),

        .led_tx_buf_id(led_tx_buf_id),
        .led_tx(led_tx),
        .led_tx_done(led_tx_done)
    );

    led_driver #(ADDR_WIDTH, DATA_WIDTH, CLK_PER) led_driver
    (
        .reset(reset),
        .clk(clk),

        // Wishbone master signals
        .wbm_address(ldrv_wbm_address),
        .wbm_writedata(ldrv_wbm_writedata),
        .wbm_readdata(ldrv_wbm_readdata),
        .wbm_strobe(ldrv_wbm_strobe),
        .wbm_cycle(ldrv_wbm_cycle),
        .wbm_write(ldrv_wbm_write),
        .wbm_ack(ldrv_wbm_ack),

        // ctrl
        .ctrl_update(led_tx),
        .ctrl_buf_id(led_tx_buf_id),
        .ctrl_update_done(led_tx_done),

        .led_data_out(led_data_out)
    );
*/

endmodule
