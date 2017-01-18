// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: led_driver_data_coder.v
// Description: Data coder for WS2812B LED driver
// -----------------------------------------------------------------------------

module led_driver_data_coder #(parameter CLK_PER = 10) // clk per in ns
(
    input clk,
    input reset,

    input tr_start,
    output tr_done,
    input tr_val,
    input tr_end,
    output led_data
);

    localparam T0H = 400; // ns
    localparam T0L = 850;
    localparam T1H = 800;
    localparam T1L = 450;
    localparam TEND = 50000;

    localparam T1H_CNT = T1H / CLK_PER;
    localparam T1L_CNT = T1L / CLK_PER;
    localparam T0H_CNT = T0H / CLK_PER;
    localparam T0L_CNT = T0L / CLK_PER;
    localparam TEND_CNT = TEND / CLK_PER;

    localparam ST_IDLE = 0;
    localparam ST_TR_1H = 1;
    localparam ST_TR_1L = 2;
    localparam ST_TR_0H = 3;
    localparam ST_TR_0L = 4;
    localparam ST_TR_END = 5;
    localparam ST_DONE = 6;

    reg [2:0] state, next_state;

    reg [15:0] clk_counter;
    wire clk_counter_done = (clk_counter == 0);

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
                if (tr_start) begin
                    next_state = tr_end ? ST_TR_END :
                                 tr_val ? ST_TR_1H  :
                                          ST_TR_0H;
                end
            end
            ST_TR_1H: begin
                if (clk_counter_done) begin
                    next_state = ST_TR_1L;
                end
            end
            ST_TR_1L: begin
                if (clk_counter_done) begin
                    next_state = ST_DONE;
                end
            end
            ST_TR_0H: begin
                if (clk_counter_done) begin
                    next_state = ST_TR_0L;
                end
            end
            ST_TR_0L: begin
                if (clk_counter_done) begin
                    next_state = ST_DONE;
                end
            end
            ST_TR_END: begin
                if (clk_counter_done) begin
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

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            clk_counter <= 0;
        end
        else begin
            if (next_state != state) begin
                case (next_state)
                    ST_TR_1H: begin clk_counter <= T1H_CNT; end
                    ST_TR_1L: begin clk_counter <= T1L_CNT; end
                    ST_TR_0H: begin clk_counter <= T0H_CNT; end
                    ST_TR_0L: begin clk_counter <= T0L_CNT; end
                    ST_TR_END: begin clk_counter <= TEND_CNT; end
                endcase
            end
            else begin
                clk_counter <= clk_counter - 1;
            end
        end
    end

    assign tr_done  = (state == ST_DONE);

    assign led_data = state == ST_TR_1H ? 1 :
                      state == ST_TR_1L ? 0 :
                      state == ST_TR_0H ? 1 :
                      state == ST_TR_0L ? 0 :
                      state == ST_TR_END ? 0 : 0;
endmodule
