// -----------------------------------------------------------------------------
// Copyright (C) 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: led_driver_wb_data.v
// Description: This moduel requests data for WS2812B LED driver for buffer
//              with buf_id
// -----------------------------------------------------------------------------

module led_driver_wb_data #(parameter ADDR_WIDTH = 16, parameter DATA_WIDTH = 32)
(
    input reset,
    input clk,

    // Wishbone master signals - for memory access
    output reg [ADDR_WIDTH-1:0] wbm_address,
    output     [DATA_WIDTH-1:0] wbm_writedata,
    input      [DATA_WIDTH-1:0] wbm_readdata,
    output     wbm_strobe,
    output     wbm_cycle,
    output     wbm_write,
    input      wbm_ack,

    // control signals
    input      [DATA_WIDTH-1:0] buf_id,
    input      wb_request_first_word,
    input      wb_request_next_word,
    output     wb_recieved_new_word,
    output     [DATA_WIDTH-1:0] wb_received_word,
    output reg [ADDR_WIDTH-1:0] wb_received_words_count
);

    `include "globals.vh"

    // WB State machine
    localparam ST_WB_IDLE           = 0;
    localparam ST_WB_REQ_FIRST_WORD = 1;
    localparam ST_WB_REQ_NEXT_WORD  = 2;

    // internal wb fsm logic
    reg [1:0] wb_state, wb_next_state;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            wb_state <= ST_WB_IDLE;
        end
        else begin
            wb_state <= wb_next_state;
        end
    end

    always @(*) begin
        wb_next_state = wb_state;
        case (wb_state)
            ST_WB_IDLE: begin
                if (wb_request_first_word) begin
                    wb_next_state = ST_WB_REQ_FIRST_WORD;
                end
                else if (wb_request_next_word) begin
                    wb_next_state = ST_WB_REQ_NEXT_WORD;
                end
            end
            ST_WB_REQ_FIRST_WORD: begin
                if (wbm_ack) begin
                    wb_next_state = ST_WB_IDLE;
                end
            end
            ST_WB_REQ_NEXT_WORD: begin
                if (wbm_ack) begin
                    wb_next_state = ST_WB_IDLE;
                end
            end
            default: begin
                wb_next_state = ST_WB_IDLE;
            end
        endcase
    end

    // WB READ ADDR 
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            wbm_address <= 0;
            wb_received_words_count <= 0;
        end
        else begin
            if (wb_request_first_word) begin
                wbm_address <= addr_for_buf_id(buf_id);
                wb_received_words_count <= 1;
            end
            else if (wb_request_next_word) begin
                wbm_address <= wbm_address + (DATA_WIDTH/8);
                wb_received_words_count <= wb_received_words_count + 1;
            end
        end
    end

    assign wb_received_word = wbm_readdata;
    assign wb_recieved_new_word = wbm_ack;

    assign wbm_strobe    = (wb_state == ST_WB_REQ_FIRST_WORD) | (wb_state == ST_WB_REQ_NEXT_WORD);
    assign wbm_cycle     = (wb_state == ST_WB_REQ_FIRST_WORD) | (wb_state == ST_WB_REQ_NEXT_WORD);
    assign wbm_write     = 0;
    assign wbm_writedata = 0;

endmodule
