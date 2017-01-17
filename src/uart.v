// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: uart.v
// Description: UART receiver controller
// -----------------------------------------------------------------------------


module uart
(
    input clk,
    input reset,
    input rx,
    output reg dataReceived,
    output reg [7:0] data
);
    
    parameter CLK_FREQ = 100_000_000;
    parameter BAUD_RATE = 57_600;
    
    `define STATE_WAIT           0
    `define STATE_WAIT_HALF_BAUD 1
    `define STATE_RECEIVING      2
    `define STATE_RECEIVED       3
    
    reg  prevRxVal, rxVal;
    reg  [1:0] curState;
    
    wire cntReset = reset | (curState == `STATE_WAIT);

    reg  baudClk;
    wire baudClk_2x;
    
    reg  [8:0] rxBuf;
    reg  [3:0] rxCount;
    
    DecCounter #( .N_PULSES(CLK_FREQ/(2*BAUD_RATE)) )
        U0 (.reset(cntReset), .clk(clk), .is_zero(baudClk_2x));
    
    // here we skip first baudClk_2x event and then count every 2nd one
    reg[1:0] divCnt;
    always @(posedge cntReset or posedge clk) begin
        if (cntReset) begin
            divCnt <= 2'b10;
            baudClk <= 0;
        end
        else begin
            if (baudClk_2x) begin
                divCnt  <= (divCnt == 0) ? 2'b01 : divCnt-1;
                baudClk <= (divCnt == 0) ? 1 : 0;
            end
            else begin
                baudClk <= 0;
            end
        end
    end
    
    
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            rxVal <= 0;
            prevRxVal <= 0;
        end
        else begin
            rxVal <= rx;
            prevRxVal <= rxVal;
        end
    end
    
    
    
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            curState <= `STATE_WAIT;
            rxCount = 0;
            
            dataReceived <= 0;
            data <= 8'b0;
        end
        else begin
            case (curState)
            
                `STATE_WAIT: begin
                    dataReceived <= 0;
                    if (prevRxVal & !rxVal) begin
                        curState <= `STATE_WAIT_HALF_BAUD;
                    end
                end
                
                `STATE_WAIT_HALF_BAUD: begin
                    if (baudClk_2x)
                        curState <= (rxVal == 0) ? `STATE_RECEIVING : `STATE_WAIT;
                end
                
                `STATE_RECEIVING: begin
                    if (baudClk) begin
                        rxBuf <= {rxVal, rxBuf[8:1]};
                        rxCount = rxCount + 1;
                        
                        if (rxCount == 9) begin
                            rxCount = 0;
                            curState <= `STATE_RECEIVED;
                        end
                    
                    end
                end
                
                `STATE_RECEIVED: begin
                    if (rxBuf[8] == 1) begin
                        dataReceived <= 1;
                        data <= rxBuf[7:0];
                    end
                    curState <= `STATE_WAIT;
                end
                
                default: begin
                    curState <= `STATE_WAIT;
                end
                
            endcase
        end
    end

    
    
endmodule
