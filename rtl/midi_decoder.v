// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: midi_decoder.v
// Description: Module for convertion serial MIDI data to the internal MIDI
//              format
// -----------------------------------------------------------------------------

`include "globals.vh"

module midi_decoder (
    input            clk,
    input            reset,
    input            dataInReady,
    input [7:0]      dataIn,

    // Parsed MIDI message
    output wire      midi_rdy,
    output reg [`MIDI_CMD_SIZE-1:0] midi_cmd,
    output reg [3:0] midi_ch_sysn,
    output reg [6:0] midi_data0,
    output reg [6:0] midi_data1
);
    
    localparam ST_WAIT_CMD = 0;
    localparam ST_WAIT_DTS = 1;
    localparam ST_WAIT_DT0 = 2;
    localparam ST_WAIT_DT1 = 3;
    localparam ST_SEND_MSG = 4;
    
    reg[2:0] state, next_state;

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            state <= ST_WAIT_CMD;
        end
        else begin
            state <= next_state;
        end
    end

    reg [3:0] ch_sysn;
    reg       skip;
    reg [1:0] npar;
    reg [`MIDI_CMD_SIZE-1:0] type;
    
    always @(dataIn) begin
        ch_sysn = dataIn[3:0];
        skip    = 1;
        npar    = 0;
        type    = `MIDI_CMD_NONE;

        case (dataIn[6:4])
        3'h0: begin skip=1'b0; npar=2'd2; type=`MIDI_CMD_NOTE_ON    ; end
        3'h1: begin skip=1'b0; npar=2'd2; type=`MIDI_CMD_NOTE_OFF   ; end
        3'h2: begin skip=1'b0; npar=2'd2; type=`MIDI_CMD_AFTERTOUCH ; end
        3'h3: begin skip=1'b0; npar=2'd2; type=`MIDI_CMD_CC         ; end
        3'h4: begin skip=1'b0; npar=2'd2; type=`MIDI_CMD_PATCH_CHG  ; end
        3'h5: begin skip=1'b0; npar=2'd1; type=`MIDI_CMD_CH_PRESSURE; end
        3'h6: begin skip=1'b0; npar=2'd2; type=`MIDI_CMD_PITCH_BEND ; end
        3'h7: begin
            case (dataIn[3:0])
            4'h0: begin skip=1'b1; npar=2'd0; type=`MIDI_CMD_SYS_EXCL_ST   ; end
            4'h1: begin skip=1'b0; npar=2'd2; type=`MIDI_CMD_SYS_TIME_QF   ; end
            4'h2: begin skip=1'b0; npar=2'd2; type=`MIDI_CMD_SYS_SONG_POS  ; end
            4'h3: begin skip=1'b0; npar=2'd2; type=`MIDI_CMD_SYS_SONG_SEL  ; end
          //4'h4: begin skip=1'b1; npar=2'd2; type=`MIDI_CMD_NONE          ; end
          //4'h5: begin skip=1'b1; npar=2'd2; type=`MIDI_CMD_NONE          ; end
            4'h6: begin skip=1'b1; npar=2'd2; type=`MIDI_CMD_SYS_TUNE_REQ  ; end
            4'h7: begin skip=1'b1; npar=2'd0; type=`MIDI_CMD_SYS_EXCL_END  ; end
            4'h8: begin skip=1'b0; npar=2'd2; type=`MIDI_CMD_SYS_TIMING_CLK; end
          //4'h9: begin skip=1'b1; npar=2'd2; type=`MIDI_CMD_NONE          ; end
            4'ha: begin skip=1'b0; npar=2'd2; type=`MIDI_CMD_SYS_START     ; end
            4'hb: begin skip=1'b0; npar=2'd2; type=`MIDI_CMD_SYS_CONT      ; end
            4'hc: begin skip=1'b0; npar=2'd2; type=`MIDI_CMD_SYS_STOP      ; end
          //4'hd: begin skip=1'b1; npar=2'd2; type=`MIDI_CMD_NONE          ; end
            4'he: begin skip=1'b1; npar=2'd2; type=`MIDI_CMD_SYS_ACT_SNS   ; end
            4'hf: begin skip=1'b0; npar=2'd2; type=`MIDI_CMD_SYS_RST       ; end
            endcase
        end
        endcase
    end


    always @(*) begin
        next_state = state;
        case (state)
            ST_WAIT_CMD:
                if (dataInReady) begin
                    next_state = (dataIn[7] == 1'b0) ? ST_WAIT_CMD :
                                 (skip      == 1'b1) ? ST_WAIT_CMD :
                                 (npar      == 2'd0) ? ST_SEND_MSG :
                                 (npar      == 2'd1) ? ST_WAIT_DTS :
                                                       ST_WAIT_DT0 ;
                end
            ST_WAIT_DTS:
                if (dataInReady) begin
                    next_state = (dataIn[7] == 1'b1) ? ST_WAIT_CMD :
                                                       ST_SEND_MSG ;
                end
            ST_WAIT_DT0:
                if (dataInReady) begin
                    next_state = (dataIn[7] == 1'b1) ? ST_WAIT_CMD :
                                                       ST_WAIT_DT1 ;
                end
            ST_WAIT_DT1:
                if (dataInReady) begin
                    next_state = (dataIn[7] == 1'b1) ? ST_WAIT_CMD :
                                                       ST_SEND_MSG ;
                end
            ST_SEND_MSG:
                next_state = ST_WAIT_CMD;
            default:
                next_state = ST_WAIT_CMD;
        endcase
    end


    assign midi_rdy = (state == ST_SEND_MSG);

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            midi_cmd     <= 0;
            midi_ch_sysn <= 0;
            midi_data0   <= 0;
            midi_data1   <= 0;
        end
        else if (state == ST_WAIT_CMD && dataInReady) begin
            midi_cmd     <= type;
            midi_ch_sysn <= ch_sysn;
            midi_data0   <= 0;
            midi_data1   <= 0;
        end
        else if (state == ST_WAIT_DTS && dataInReady) begin
            midi_data0   <= dataIn[6:0];
        end
        else if (state == ST_WAIT_DT0 && dataInReady) begin
            midi_data0   <= dataIn[6:0];
        end
        else if (state == ST_WAIT_DT1 && dataInReady) begin
            midi_data1   <= dataIn[6:0];
        end
    end
endmodule
