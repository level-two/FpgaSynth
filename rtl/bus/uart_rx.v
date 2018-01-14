// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: uart_rx.v
// Description: UART receiver controller
// -----------------------------------------------------------------------------

module uart_rx #(parameter CLK_FREQ = 100_000_000, parameter BAUD_RATE = 57_600)
(
    input        clk,
    input        reset,
    input        rx,
    output       data_received,
    output [7:0] data
);
    
    localparam ST_IDLE               = 0;
    localparam ST_WAIT_HALF_BAUD     = 1;
    localparam ST_FIRST_BIT_RECEIVED = 2;
    localparam ST_WAIT_BAUD          = 3;
    localparam ST_RECEIVED           = 4;
    localparam ST_DONE               = 5;

    localparam BAUD_CNT              = CLK_FREQ/BAUD_RATE;
    localparam HALF_BAUD_CNT         = BAUD_CNT/2;
    
    reg  [2:0] state, next_state;
    reg  [8:0] rxBuf;
    
    

    //========================
    crossdomain_signal bclk_crossdomain (
        .reset        (reset    ),
        .clk_b        (clk      ),
        .sig_domain_a (rx       ),
        .sig_domain_b (rx_s     )
    );

    reg rx_s_dly;
    always @(posedge clk) begin
        if (reset) begin
            rx_s_dly <= 1'b0;
        end
        else begin
            rx_s_dly <= rx_s;
        end
    end
    

    reg [13:0] baud_cnt;
    wire baud_tick      = (baud_cnt == BAUD_CNT-1);
    wire half_baud_tick = (baud_cnt == HALF_BAUD_CNT-1);
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            baud_cnt <= 0;
        end
        else begin
            if (state == ST_WAIT_HALF_BAUD || state == ST_WAIT_BAUD) begin
                baud_cnt <= baud_cnt + 1;
            end
            else begin
                baud_cnt <= 0;
            end
        end
    end
    

    always @(*) begin
        next_state = state;
        case (state)
            ST_IDLE: begin
                if (rx_s_dly == 1'b1 && rx_s == 1'b0) begin
                    next_state = ST_WAIT_HALF_BAUD;
                end
            end
            ST_WAIT_HALF_BAUD: begin
                if (half_baud_tick == 1) begin
                    next_state = ST_FIRST_BIT_RECEIVED;
                end
            end
            ST_FIRST_BIT_RECEIVED: begin
                next_state = (rx_s == 1'b0) ? ST_WAIT_BAUD : ST_IDLE;
            end
            ST_WAIT_BAUD: begin
                if (baud_tick == 1) begin
                    next_state = ST_RECEIVED;
                end
            end
            ST_RECEIVED: begin
                next_state = (rx_count == 4'h8) ? ST_DONE : ST_WAIT_BAUD;
            end
            ST_DONE: begin
                next_state = ST_IDLE;
            end
            default: begin
                next_state = ST_IDLE;
            end
        endcase
    end


    always @(posedge reset or posedge clk) begin
        if (reset) begin
            state <= ST_IDLE;
        end
        else begin
            state <= next_state;
        end
    end
    

    assign data_received = (state == ST_DONE && rxBuf[8] == 1);
    assign data = rxBuf[7:0];


    reg  [3:0] rx_count;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            rx_count <= 0;
        end
        else if (state == ST_IDLE) begin
            rx_count <= 0;
        end
        else if (state == ST_RECEIVED) begin
            rx_count <= rx_count + 1;
        end
    end

    
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            rxBuf <= 0;
        end
        else if (state == ST_RECEIVED) begin
            rxBuf <= {rx_s, rxBuf[8:1]};
        end
    end
endmodule
