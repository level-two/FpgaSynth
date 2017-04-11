//-----------------------------------------------------
// Design Name : syn_fifo
// File Name   : syn_fifo.v
// Function    : Synchronous (single clock) FIFO
// Coder       : Deepak Kumar Tala
//-----------------------------------------------------
module syn_fifo (
    input                   clk,
    input                   rst,
    input                   wr,
    input                   rd,
    input  [DATA_WIDTH-1:0] data_in,
    output [DATA_WIDTH-1:0] data_out,
    output                  empty,
    output                  full
);    
 
// FIFO constants
parameter DATA_WIDTH = 8;
parameter ADDR_WIDTH = 8;
parameter RAM_DEPTH = (1 << ADDR_WIDTH);

//-----------Internal variables-------------------
reg  [ADDR_WIDTH-1:0] wr_pointer;
reg  [ADDR_WIDTH-1:0] rd_pointer;
reg  [ADDR_WIDTH-1:0] status_cnt;
wire [DATA_WIDTH-1:0] data_ram;

//-----------Variable assignments---------------
assign full = (status_cnt == RAM_DEPTH);
assign empty = (status_cnt == 0);

//-----------Code Start---------------------------
always @ (posedge clk or posedge rst) begin
    if (rst) begin
        wr_pointer <= 0;
    end else if (wr) begin
        if (wr_pointer < RAM_DEPTH-1) begin
            wr_pointer <= wr_pointer + 1;
        end
        else begin
            wr_pointer <= 0;
        end
    end
end

always @ (posedge clk or posedge rst) begin
    if (rst) begin
        rd_pointer <= 0;
    end else if (rd) begin
        if (rd_pointer < RAM_DEPTH-1) begin
            rd_pointer <= rd_pointer + 1;
        end
        else begin
            rd_pointer <= 0;
        end
    end
end

assign data_out = data_ram;

always @ (posedge clk or posedge rst)
begin : STATUS_COUNTER
  if (rst) begin
    status_cnt <= 0;
  // Read but no write.
  end else if (rd && !wr && (status_cnt != 0)) begin
    status_cnt <= status_cnt - 1;
  // Write but no read.
  end else if (wr && !rd && (status_cnt != RAM_DEPTH)) begin
    status_cnt <= status_cnt + 1;
  end
end 

dp_ram #(DATA_WIDTH, ADDR_WIDTH, RAM_DEPTH) dp_ram_inst
(
    .clk     (clk)        ,
    .wr_addr (wr_pointer) ,
    .wr_data (data_in)    ,
    .wr      (wr)         ,
    .rd_addr (rd_pointer) ,
    .rd_data (data_ram)   ,
    .rd      (rd)
);     

endmodule
