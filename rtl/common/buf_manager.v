// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: buf_manager.v
// Description: Buffer manager. Accessed via wishbone bus
//              Read: getting buffer
//              Write: return of previously retained buffer
// -----------------------------------------------------------------------------


module buf_manager (
        input      reset,
        input      clk,

        input      [ADDR_WIDTH-1:0] wbs_address,
        input      [DATA_WIDTH-1:0] wbs_writedata,
        output     [DATA_WIDTH-1:0] wbs_readdata,
        input      wbs_strobe,
        input      wbs_cycle,
        input      wbs_write,
        output     wbs_ack
    );

    `include "globals.vh"

    parameter ADDR_WIDTH = 16;
    parameter DATA_WIDTH = 32;
    parameter NBUFS = 4;


    reg read_ack;
    reg write_ack;

    wire component_write;
    wire component_read;
    wire [ADDR_WIDTH-1:0] component_addr;
    wire [DATA_WIDTH-1:0] component_write_data;
    wire [DATA_WIDTH-1:0] component_read_data;


    assign component_trans = wbs_strobe & wbs_cycle;
    reg component_trans_dly;
    always @(posedge clk or posedge reset) begin
        if (reset) begin 
            component_trans_dly <= 1'h0;
        end else begin
            component_trans_dly <= component_trans;
        end
    end



    assign component_write = component_trans & ~component_trans_dly & wbs_write;
    assign wbs_ack = (read_ack | write_ack) & component_trans;


    always @(posedge clk or posedge reset) begin
        if (reset) begin 
            write_ack <= 1'h0;
        end else begin
            write_ack <= component_write;
        end
    end


    assign component_read = component_trans & ~component_trans_dly & ~wbs_write;


    always @(posedge clk or posedge reset) begin
        if (reset) begin
            read_ack     <= 1'h0;
        end else begin
            read_ack     <= component_read;
        end
    end

    assign wbs_readdata         = component_read_data;

    assign component_addr       = addr_without_base(wbs_address);
    assign component_write_data = wbs_writedata;

    // fifo push-pop operation
    assign component_read_data = fifo_empty ? {DATA_WIDTH{1'b1}} : fifo_buf_out;

    wire fifo_buf_push = init_fifo | component_write;

    reg fifo_buf_pop;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            fifo_buf_pop = 0;
        end
        else begin
            fifo_buf_pop = component_read;
        end 
    end

    wire [DATA_WIDTH-1:0] fifo_buf_in = init_fifo       ? fifo_buf_id_cnt :
                                        component_write ? component_write_data : 0;
    reg  init_fifo;
    reg  [DATA_WIDTH-1:0] fifo_buf_id_cnt;
    wire [DATA_WIDTH-1:0] fifo_buf_out;
    wire fifo_empty;

    // init fifo
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            fifo_buf_id_cnt <= 0;
            init_fifo       <= 1;
        end
        else if (init_fifo) begin
            fifo_buf_id_cnt <= fifo_buf_id_cnt + 1;
            if (fifo_buf_id_cnt == NBUFS-1) begin
                init_fifo <= 0;
            end
        end 
    end


    // inst fifo with N buf_id's
    syn_fifo #(DATA_WIDTH, ADDR_WIDTH, NBUFS)
    buf_fifo(
        .clk(clk),
        .rst(reset),
        .wr(fifo_buf_push),
        .rd(fifo_buf_pop),
        .data_in(fifo_buf_in),
        .data_out(fifo_buf_out),
        .empty(fifo_empty),
        .full()      
    );
endmodule
