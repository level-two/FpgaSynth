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

    output [3:0]  reg_1_field_0,
    output [2:0]  reg_1_field_1,
    output [0:0]  reg_1_field_2,
    output [7:0]  reg_1_field_3,

    input  [7:0]  reg_2_field_0,
    input  [7:0]  reg_2_field_1,
    input  [7:0]  reg_2_field_2,
    input  [7:0]  reg_2_field_3
);

    parameter ADDR_WIDTH = 16;
    parameter DATA_WIDTH = 32;

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
    reg  [DATA_WIDTH-1:0] read_data;
    assign wbs_readdata = read_data;


    reg  [31:0] reg_0_rw_reg;
    reg  [31:0] reg_1_rw_reg;
    wire [31:0] reg_2_ro_reg;
    reg  [31:0] reg_3_const_reg;


    always @(*) begin
        case (addr[7:0])
            8'h00:   read_data <= reg_0_rw_reg;
            8'h04:   read_data <= reg_1_rw_reg;
            8'h08:   read_data <= reg_2_ro_reg;
            8'h0c:   read_data <= reg_3_const_reg;
            default: read_data <= 32'h00000000;
        endcase
    end


    always @(posedge clk or posedge reset) begin
        if (reset) begin 
            // default values
            reg_0_rw_reg    <= 32'h01010101;
            reg_1_rw_reg    <= 32'h00ffff00;
            reg_3_const_reg <= 32'hdeadbeef;
        end 
        else if (write) begin
            case (addr[7:0])
                8'h00: begin reg_0_rw_reg <= write_data; end
                8'h04: begin reg_1_rw_reg <= write_data; end
                8'h08: begin end
                8'h0c: begin end
            endcase
        end
    end

    // reg_0 RW
    assign reg_0 = reg_0_rw_reg; 

    // reg_1 RW
    assign reg_1_field_0 = reg_1_rw_reg[3:0]; 
    assign reg_1_field_1 = reg_1_rw_reg[5:4]; 
    assign reg_1_field_2 = reg_1_rw_reg[6:6]; 
    assign reg_1_field_3 = reg_1_rw_reg[14:7]; 

    // reg_2 RO
    assign reg_2_ro_reg[7:0]   = reg_2_field_0;
    assign reg_2_ro_reg[15:8]  = reg_2_field_1;  
    assign reg_2_ro_reg[23:16] = reg_2_field_2; 
    assign reg_2_ro_reg[31:24] = reg_2_field_3; 

    // reg_3 CONST

endmodule
