// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: sdram_ctrl_wb.v
// Description: Wishbone interface implementation for the sdram driver
// -----------------------------------------------------------------------------


module sdram_wb
(
    input             clk                 ,
    input             reset               ,
                                          
    // WISHBONE SLAVE INTERFACE           
    input  [31:0]     wbs_address         ,
    input  [15:0]     wbs_writedata       ,
    output [15:0]     wbs_readdata        ,
    input             wbs_strobe          ,
    input             wbs_cycle           ,
    input             wbs_write           ,
    output            wbs_ack             ,
    output            wbs_stall           ,
    //output          wbs_err             , // TBI
                                          
    output [31:0]     sdram_ctrl_addr          , // Cur cmd adddr from CMD fifo
    output            sdram_ctrl_wr_nrd        , // Cur w/r from CMD fifo
    output            sdram_ctrl_cmd_ready     , // CMD fifo is not emty
    input             sdram_ctrl_cmd_accepted  , // POP prev cmd from CMD fifo
    input             sdram_ctrl_cmd_done      , // Send ack that command is done
    output [15:0]     sdram_ctrl_wr_data       , // To fifo
    input  [15:0]     sdram_ctrl_rd_data       , // From SDRAM
    output            sdram_ctrl_access         
    //input           sdram_ctrl_op_err        , // TBI
);

    localparam FIFO_DW  = 32+1+16;

    wire   wbs_trans    = wbs_strobe & wbs_cycle;
    assign wbs_stall    = fifo_full; 
    assign wbs_ack      = sdram_ctrl_cmd_done;
    assign wbs_readdata = sdram_ctrl_rd_data;
    //assign wbs_err    = sdram_ctrl_op_err; // TBI

    wire               fifo_push;
    wire               fifo_pop;
    wire [FIFO_DW-1:0] fifo_data_in;
    wire [FIFO_DW-1:0] fifo_data_out;
    wire               fifo_empty;
    wire               fifo_full;

    assign sdram_ctrl_access    = wbs_cycle;
    assign fifo_push            = wbs_strobe && !fifo_full;
    assign fifo_pop             = sdram_ctrl_cmd_accepted && !fifo_empty;
    assign fifo_data_in         = {wbs_address, wbs_write, wbs_writedata};
    assign sdram_ctrl_cmd_ready = !fifo_empty;
    assign {sdram_ctrl_addr, sdram_ctrl_wr_nrd, sdram_ctrl_wr_data} = fifo_data_out;

    syn_fifo #(
        .DATA_W     (           FIFO_DW),
        .ADDR_W     (                 4),
        .FIFO_DEPTH (                16)
    ) cmd_fifo_inst (
        .clk        (clk               ),
        .rst        (reset             ),
        .wr         (fifo_push         ),
        .rd         (fifo_pop          ),
        .data_in    (fifo_data_in      ),
        .data_out   (fifo_data_out     ),
        .empty      (fifo_empty        ),
        .full       (fifo_full         )
    );    
endmodule
