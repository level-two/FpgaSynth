// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: syn_fifo.v
// Description: Synchronous FIFO
// -----------------------------------------------------------------------------

module syn_fifo (
    input               clk,
    input               rst,
    input               wr,
    input               rd,
    input  [DATA_W-1:0] data_in,
    output [DATA_W-1:0] data_out,
    output              empty,
    output              full
);    
     
    parameter DATA_W     = 8;
    parameter ADDR_W     = 8;
    parameter FIFO_DEPTH = (1 << ADDR_W);


    reg  [ADDR_W-1:0]   wr_pointer;
    reg  [ADDR_W-1:0]   rd_pointer;
    reg  [ADDR_W:0]     status_cnt;
    wire [DATA_W-1:0]   rd_data;

    assign full  = (status_cnt == FIFO_DEPTH);
    assign empty = (status_cnt == 0);

    always @ (posedge clk or posedge rst) begin
        if (rst) begin
            wr_pointer <= 0;
        end else if (wr) begin
            if (wr_pointer == FIFO_DEPTH-1) begin
                wr_pointer <= 0;
            end
            else begin
                wr_pointer <= wr_pointer + 1;
            end
        end
    end

    always @ (posedge clk or posedge rst) begin
        if (rst) begin
            rd_pointer <= 0;
        end else if (rd) begin
            if (rd_pointer == FIFO_DEPTH-1) begin
                rd_pointer <= 0;
            end
            else begin
                rd_pointer <= rd_pointer + 1;
            end
        end
    end

    assign data_out = rd_data;

    always @ (posedge clk or posedge rst) begin
        if (rst) begin
            status_cnt <= 0;
        end else if (rd && !wr && (status_cnt != 0)) begin
            status_cnt <= status_cnt - 1;
        end else if (wr && !rd && (status_cnt != FIFO_DEPTH)) begin
            status_cnt <= status_cnt + 1;
        end
    end 


    dp_ram #(
        .DATA_W    (DATA_W     ),
        .ADDR_W    (ADDR_W     ),
        .RAM_DEPTH (FIFO_DEPTH )
    ) dp_ram_inst (
        .clk       (clk        ),
        .wr_addr   (wr_pointer ),
        .wr_data   (data_in    ),
        .wr        (wr         ),
        .rd_addr   (rd_pointer ),
        .rd_data   (rd_data    ),
        .rd        (rd         )
    );     
endmodule
