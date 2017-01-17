// -----------------------------------------------------------------------------
// Copyright (C) 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: led_driver.v
// Description: WS2812B LED driver with wishbone interface 
// -----------------------------------------------------------------------------

module led_driver #(parameter ADDR_WIDTH = 16, parameter DATA_WIDTH = 32, parameter CLK_PER = 10)
(
    input       reset,
    input       clk,

    // Wishbone master signals - for memory access
    output      [ADDR_WIDTH-1:0] wbm_address,
    output      [DATA_WIDTH-1:0] wbm_writedata,
    input       [DATA_WIDTH-1:0] wbm_readdata,
    output      wbm_strobe,
    output      wbm_cycle,
    output      wbm_write,
    input       wbm_ack,

    // Signals from contorll logic
    input       ctrl_update,
    input       [DATA_WIDTH-1:0] ctrl_buf_id,
    output      ctrl_update_done,

    // led driver output
    output      led_data_out
);

    `include "globals.vh"


    // FSM
    localparam ST_IDLE             = 0;
    localparam ST_REQ_FIRST_WORD   = 1;
    localparam ST_REQ_NEXT_WORD    = 2;
    localparam ST_WAIT_WORD        = 3;
    localparam ST_TRANSMIT_WORD    = 4;
    localparam ST_WORD_TRANSMITTED = 5;
    localparam ST_SEND_BIT         = 6;
    localparam ST_BIT_SENT         = 7;
    localparam ST_SEND_END         = 8;
    localparam ST_DONE             = 9;
    
    reg [3:0] state, next_state;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= ST_IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            ST_IDLE: begin
                if (ctrl_update) begin
                    next_state = ST_REQ_FIRST_WORD;
                end
            end
            ST_REQ_FIRST_WORD : begin
                next_state = ST_WAIT_WORD;
            end
            ST_WAIT_WORD : begin
                if (wb_recieved_new_word) begin
                    next_state = ST_TRANSMIT_WORD;
                end
            end
            ST_TRANSMIT_WORD: begin
                if (last_word) begin
                    next_state = ST_SEND_BIT;
                end
                else begin
                    next_state = ST_REQ_NEXT_WORD;
                end
            end
            ST_REQ_NEXT_WORD : begin
                next_state = ST_SEND_BIT;
            end
            ST_SEND_BIT: begin
                if (led_bit_sent) begin
                    next_state = last_bit ? ST_WORD_TRANSMITTED : ST_BIT_SENT;
                end
            end
            ST_BIT_SENT: begin
                next_state = ST_SEND_BIT;
            end
            ST_WORD_TRANSMITTED: begin
                next_state = last_word ? ST_SEND_END : ST_TRANSMIT_WORD;
            end
            ST_SEND_END: begin
                if (led_bit_sent) begin
                    next_state = ST_DONE;
                end
            end
            ST_DONE: begin
                next_state = ST_IDLE;
            end
            default: begin
                next_state = ST_IDLE;
            end
        endcase
    end


    reg last_word;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            last_word <= 0;
        end
        else if (state == ST_IDLE) begin
            last_word <= 0;
        end
        else if (state == ST_WORD_TRANSMITTED) begin
            last_word <= (wb_received_words_count == `IMG_HEIGHT);
        end
    end


    wire wb_request_first_word = (state == ST_REQ_FIRST_WORD);
    wire wb_request_next_word  = (state == ST_REQ_NEXT_WORD);

    wire led_end = (state == ST_SEND_END);
    assign ctrl_update_done = (state == ST_DONE);


    // shift reg wires
    wire [`LED_DATA_WIDTH-1:0] led_data_word = wbm_readdata[`LED_DATA_WIDTH-1:0];
    wire load  = (state == ST_TRANSMIT_WORD);
    wire next_bit = (state == ST_BIT_SENT);
    wire led_bit_val;
    wire last_bit;


    wire wb_recieved_new_word;
    wire [DATA_WIDTH-1:0] wb_received_word;
    wire [ADDR_WIDTH-1:0] wb_received_words_count;

    led_driver_wb_data #(ADDR_WIDTH, DATA_WIDTH) wb_data
    (
        .reset(reset),
        .clk(clk),

        .wbm_address(wbm_address),
        .wbm_writedata(wbm_writedata),
        .wbm_readdata(wbm_readdata),
        .wbm_strobe(wbm_strobe),
        .wbm_cycle(wbm_cycle),
        .wbm_write(wbm_write),
        .wbm_ack(wbm_ack),

        .buf_id(ctrl_buf_id),
        .wb_request_first_word(wb_request_first_word),
        .wb_request_next_word(wb_request_next_word),
        .wb_recieved_new_word(wb_recieved_new_word),
        .wb_received_word(wb_received_word),
        .wb_received_words_count(wb_received_words_count)
    );


    // store recieved word for further use
    reg [DATA_WIDTH-1:0] rcvd_word;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rcvd_word <= 0;
        end
        else if (wb_recieved_new_word) begin
            rcvd_word <= wb_received_word;
        end
    end


    led_driver_shift_reg#(DATA_WIDTH, `LED_DATA_WIDTH) shift_reg
    (
        .clk(clk),
        .reset(reset),

        .data_in(rcvd_word),
        .load(load),
        .next_bit(next_bit),
        .bit_val(led_bit_val),
        .last_bit(last_bit)
    );

    wire send_led_bit = (state == ST_SEND_BIT) | (state == ST_SEND_END);
    wire led_bit_sent;

    led_driver_data_coder#(CLK_PER) data_coder
    (
        .clk(clk),
        .reset(reset),

        .tr_start(send_led_bit),
        .tr_done(led_bit_sent),
        .tr_val(led_bit_val),
        .tr_end(led_end),
        .led_data(led_data_out)
    );

endmodule
