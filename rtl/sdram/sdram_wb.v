// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: sdram_wb.v
// Description: Wishbone interface implementation for the sdram driver
// -----------------------------------------------------------------------------


module sdram_wb
(
    input             clk           ,
    input             reset         ,

    // WISHBONE SLAVE INTERFACE
    input  [31:0]     wbs_address   ,
    input  [15:0]     wbs_writedata ,
    output [15:0]     wbs_readdata  ,
    input             wbs_strobe    ,
    input             wbs_cycle     ,
    input             wbs_write     ,
    output            wbs_ack       ,
    //output          wbs_err       , // TBI

    output [31:0]     sdram_addr    ,
    output            sdram_wr      ,
    output            sdram_rd      ,
    output [15:0]     sdram_wr_data ,
    input  [15:0]     sdram_rd_data ,
    input             sdram_op_done  
    //input           sdram_op_err  , // TBI
);

    reg  wb_trans_dly;
    wire wb_trans = wbs_strobe & wbs_cycle;

    always @(posedge clk or posedge reset) begin
        if (reset) wb_trans_dly <= 1'h0;
        else       wb_trans_dly <= wb_trans;
    end

    assign sdram_rd      = wb_trans & ~wb_trans_dly & ~wbs_write;
    assign sdram_wr      = wb_trans & ~wb_trans_dly & wbs_write;
    assign wbs_ack       = sdram_op_done;
    //assign wbs_err     = sdram_op_err; // TBI
    assign sdram_addr    = wbs_address;
    assign sdram_wr_data = wbs_writedata;
    assign wbs_readdata  = sdram_rd_data;
endmodule
