// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: nic_modules.v
// Description: Wishbone NIC for different modules
// -----------------------------------------------------------------------------


module wb_nic #(parameter ADDR_WIDTH = 32, parameter DATA_WIDTH = 32)
(
    input                       reset,
    input                       clk,

    // Masters
    input      [ADDR_WIDTH-1:0] ctrl_wbm_address,
    input      [DATA_WIDTH-1:0] ctrl_wbm_writedata,
    output     [DATA_WIDTH-1:0] ctrl_wbm_readdata,
    input                       ctrl_wbm_strobe,
    input                       ctrl_wbm_cycle,
    input                       ctrl_wbm_write,
    output                      ctrl_wbm_ack,

    input      [ADDR_WIDTH-1:0] ldrv_wbm_address,
    input      [DATA_WIDTH-1:0] ldrv_wbm_writedata,
    output     [DATA_WIDTH-1:0] ldrv_wbm_readdata,
    input                       ldrv_wbm_strobe,
    input                       ldrv_wbm_cycle,
    input                       ldrv_wbm_write,
    output                      ldrv_wbm_ack,

    input      [ADDR_WIDTH-1:0] imgd_wbm_address,
    input      [DATA_WIDTH-1:0] imgd_wbm_writedata,
    output     [DATA_WIDTH-1:0] imgd_wbm_readdata,
    input                       imgd_wbm_strobe,
    input                       imgd_wbm_cycle,
    input                       imgd_wbm_write,
    output                      imgd_wbm_ack,

    input      [ADDR_WIDTH-1:0] imgr_wbm_address,
    input      [DATA_WIDTH-1:0] imgr_wbm_writedata,
    output     [DATA_WIDTH-1:0] imgr_wbm_readdata,
    input                       imgr_wbm_strobe,
    input                       imgr_wbm_cycle,
    input                       imgr_wbm_write,
    output                      imgr_wbm_ack,

    // Slaves
    output     [ADDR_WIDTH-1:0] spi_wbs_address,
    output     [DATA_WIDTH-1:0] spi_wbs_writedata,
    input      [DATA_WIDTH-1:0] spi_wbs_readdata,
    output                      spi_wbs_strobe,
    output                      spi_wbs_cycle,
    output                      spi_wbs_write,
    input                       spi_wbs_ack,

    output     [ADDR_WIDTH-1:0] bmgr_wbs_address,
    output     [DATA_WIDTH-1:0] bmgr_wbs_writedata,
    input      [DATA_WIDTH-1:0] bmgr_wbs_readdata,
    output                      bmgr_wbs_strobe,
    output                      bmgr_wbs_cycle,
    output                      bmgr_wbs_write,
    input                       bmgr_wbs_ack,

    output     [ADDR_WIDTH-1:0] mem_wbs_address,
    output     [DATA_WIDTH-1:0] mem_wbs_writedata,
    input      [DATA_WIDTH-1:0] mem_wbs_readdata,
    output                      mem_wbs_strobe,
    output                      mem_wbs_cycle,
    output                      mem_wbs_write,
    input                       mem_wbs_ack
);

    `include "globals.vh"

    localparam MASTERS_NUM = 4;
    localparam SLAVES_NUM  = 3;

    wire [MASTERS_NUM-1:0] req;
    wire [MASTERS_NUM-1:0] gnt;

    assign req = {ctrl_wbm_cycle, ldrv_wbm_cycle, imgd_wbm_cycle, imgr_wbm_cycle};

    arb_rr #(MASTERS_NUM) arb_rr_inst
    (
        .reset(reset),
        .clk(clk),
        .req(req),
        .gnt(gnt)
    );

    reg  [ADDR_WIDTH-1:0] slave_wbs_address;
    reg  [DATA_WIDTH-1:0] slave_wbs_writedata;
    wire [DATA_WIDTH-1:0] slave_wbs_readdata;
    wire                  slave_wbs_ack;
    reg                   slave_wbs_strobe;
    reg                   slave_wbs_cycle;
    reg                   slave_wbs_write;

    always @(*) begin
        case (gnt)
            'b1: begin
                slave_wbs_address   = imgr_wbm_address;
                slave_wbs_writedata = imgr_wbm_writedata;
                slave_wbs_strobe    = imgr_wbm_strobe;
                slave_wbs_cycle     = imgr_wbm_cycle;
                slave_wbs_write     = imgr_wbm_write;
            end
            'b10: begin
                slave_wbs_address   = imgd_wbm_address;
                slave_wbs_writedata = imgd_wbm_writedata;
                slave_wbs_strobe    = imgd_wbm_strobe;
                slave_wbs_cycle     = imgd_wbm_cycle;
                slave_wbs_write     = imgd_wbm_write;
            end
            'b100: begin
                slave_wbs_address   = ldrv_wbm_address;
                slave_wbs_writedata = ldrv_wbm_writedata;
                slave_wbs_strobe    = ldrv_wbm_strobe;
                slave_wbs_cycle     = ldrv_wbm_cycle;
                slave_wbs_write     = ldrv_wbm_write;
            end
            'b1000: begin
                slave_wbs_address   = ctrl_wbm_address;
                slave_wbs_writedata = ctrl_wbm_writedata;
                slave_wbs_strobe    = ctrl_wbm_strobe;
                slave_wbs_cycle     = ctrl_wbm_cycle;
                slave_wbs_write     = ctrl_wbm_write;
            end
            default: begin
                slave_wbs_address   = 0;
                slave_wbs_writedata = 0;
                slave_wbs_strobe    = 0;
                slave_wbs_cycle     = 0;
                slave_wbs_write     = 0;
            end
        endcase
    end

    assign imgr_wbm_ack = gnt[0] ? slave_wbs_ack : 0;
    assign imgd_wbm_ack = gnt[1] ? slave_wbs_ack : 0;
    assign ldrv_wbm_ack = gnt[2] ? slave_wbs_ack : 0;
    assign ctrl_wbm_ack = gnt[3] ? slave_wbs_ack : 0;

    assign imgr_wbm_readdata = gnt[0] ? slave_wbs_readdata : 0;
    assign imgd_wbm_readdata = gnt[1] ? slave_wbs_readdata : 0;
    assign ldrv_wbm_readdata = gnt[2] ? slave_wbs_readdata : 0;
    assign ctrl_wbm_readdata = gnt[3] ? slave_wbs_readdata : 0;


    assign spi_wbs_address   = slave_wbs_address;
    assign spi_wbs_writedata = slave_wbs_writedata;
    assign spi_wbs_write     = slave_wbs_write;
    assign spi_wbs_cycle     = (addr_base(slave_wbs_address) == `SPI_BASE) ? slave_wbs_cycle   : 0;
    assign spi_wbs_strobe    = (addr_base(slave_wbs_address) == `SPI_BASE) ? slave_wbs_strobe  : 0;

    assign bmgr_wbs_address   = slave_wbs_address;
    assign bmgr_wbs_writedata = slave_wbs_writedata;
    assign bmgr_wbs_write     = slave_wbs_write;
    assign bmgr_wbs_cycle     = (addr_base(slave_wbs_address) == `BUF_MANAGER_BASE) ? slave_wbs_cycle   : 0;
    assign bmgr_wbs_strobe    = (addr_base(slave_wbs_address) == `BUF_MANAGER_BASE) ? slave_wbs_strobe  : 0;

    assign mem_wbs_address    = slave_wbs_address;
    assign mem_wbs_writedata  = slave_wbs_writedata;
    assign mem_wbs_write      = slave_wbs_write;
    assign mem_wbs_cycle      = (addr_base(slave_wbs_address) == `MEM_BASE) ? slave_wbs_cycle  : 0;
    assign mem_wbs_strobe     = (addr_base(slave_wbs_address) == `MEM_BASE) ? slave_wbs_strobe : 0;


    assign slave_wbs_ack      = (addr_base(slave_wbs_address) == `SPI_BASE)         ? spi_wbs_ack  :
                                (addr_base(slave_wbs_address) == `BUF_MANAGER_BASE) ? bmgr_wbs_ack :
                                (addr_base(slave_wbs_address) == `MEM_BASE)         ? mem_wbs_ack  : 0;

    assign slave_wbs_readdata = (addr_base(slave_wbs_address) == `SPI_BASE)         ? spi_wbs_readdata  :
                                (addr_base(slave_wbs_address) == `BUF_MANAGER_BASE) ? bmgr_wbs_readdata :
                                (addr_base(slave_wbs_address) == `MEM_BASE)         ? mem_wbs_readdata  : 0;
endmodule
