// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: gen_pulse_reg.v
// Description: Configuration registers for the pulse generator
// -----------------------------------------------------------------------------

module gen_pulse_reg (
    input reset,
    input clk,

    // Wishbone signals
    input  [ADDR_WIDTH-1:0] wbs_address,
    input  [DATA_WIDTH-1:0] wbs_writedata,
    output [DATA_WIDTH-1:0] wbs_readdata,
    input  wbs_strobe,
    input  wbs_cycle,
    input  wbs_write,
    output wbs_ack,

    output [31:0] reg_0,

    output [31:0] reg_1,
    output [3:0]  reg_1_field_0,
    output [2:0]  reg_1_field_1,
    output [0:0]  reg_1_field_2,
    output [7:0]  reg_1_field_3

    // output [DATA_WIDTH-1:0] reg_wo_0,
    // output [DATA_WIDTH-1:0] reg_wo_1,
    // output [DATA_WIDTH-1:0] reg_rw_0,
    // output [DATA_WIDTH-1:0] reg_rw_1
);

    parameter ADDR_WIDTH = 16;
    parameter DATA_WIDTH = 32;


    localparam REG_0_ADDR = 8'h0;
    localparam REG_1_ADDR = 8'h1;


    reg  read_ack;
    reg  write_ack;
    wire trans     = wbs_strobe & wbs_cycle;
    wire write     = trans & wbs_write;
    wire read      = trans & ~wbs_write;
    assign wbs_ack = (read_ack | write_ack) & trans;


    always @(posedge clk or posedge reset) begin
        if (reset) begin 
            write_ack <= 1'b0;
            read_ack  <= 1'b0;
        end else begin
            write_ack <= write;
            read_ack  <= read;
        end
    end


    wire [ADDR_WIDTH-1:0] addr       = wbs_address;
    wire [DATA_WIDTH-1:0] write_data = wbs_writedata;
    wire [DATA_WIDTH-1:0] read_data;
    assign wbs_readdata = read_data;


    // reg_0
    reg [31:0] reg_0_rw_reg;
    assign reg_0 = reg_0_rw_reg; 

    wire reg_0_selected = (addr[7:0] == REG_0_ADDR);
    wire reg_0_read     = reg_0_selected & read;
    wire reg_0_write    = reg_0_selected & write;

    always @(posedge clk or posedge reset) begin
        if (reset) begin 
            reg_0_rw_reg <= 32'h00000000; // default value
        end 
        else if (reg_0_write) begin
            reg_0_rw_reg <= write_data;
        end
    end

    wire [31:0] reg_0_read_data = reg_0_rw_reg & {DATA_WIDTH{reg_0_read}};


    // reg_1
    reg [31:0] reg_1_rw_reg;
    assign reg_1         = reg_1_rw_reg; 
    assign reg_1_field_0 = reg_1_rw_reg[3:0]; 
    assign reg_1_field_1 = reg_1_rw_reg[5:4]; 
    assign reg_1_field_2 = reg_1_rw_reg[6:6]; 
    assign reg_1_field_3 = reg_1_rw_reg[14:7]; 

    wire reg_1_selected = (addr[7:0] == REG_1_ADDR);
    wire reg_1_read     = reg_1_selected & read;
    wire reg_1_write    = reg_1_selected & write;

    always @(posedge clk or posedge reset) begin
        if (reset) begin 
            reg_1_rw_reg <= 32'h00000000; // default value
        end 
        else if (reg_1_write) begin
            reg_1_rw_reg <= write_data;
        end
    end

    wire [31:0] reg_1_read_data = reg_1_rw_reg & {DATA_WIDTH{reg_1_read}};


    // Aggregate read data and send it to the output
    assign read_data =
        reg_0_read_data |
        reg_1_read_data;

endmodule
