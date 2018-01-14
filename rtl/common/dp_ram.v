// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: dp_ram.v
// Description: Simple dual-port r-w RAM
// -----------------------------------------------------------------------------

module dp_ram (
    input               clk,
    input               wr,
    input  [ADDR_W-1:0] wr_addr,
    input  [DATA_W-1:0] wr_data,
    input               rd,
    input  [ADDR_W-1:0] rd_addr,
    output [DATA_W-1:0] rd_data
); 

    parameter DATA_W    = 8;
    parameter ADDR_W    = 8;
    parameter RAM_DEPTH = 1 << ADDR_W;


    //--------------Internal variables---------------- 
    reg [DATA_W-1:0] mem [0:RAM_DEPTH-1];


    // Memory Write Block 
    always @ (posedge clk) begin
        if (wr) begin
            mem[wr_addr] <= wr_data;
        end
    end

    // Memory Read Block 
    assign rd_data = mem[rd_addr]; 
endmodule
