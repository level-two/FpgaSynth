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

module MidiDecoder(
    input clk,
    input reset,
    input dataInReady,
    input [7:0] dataIn,
    output reg midiReady,
    output reg[3:0] midiChannel,
    output reg[2:0] midiCommand,
    output reg[6:0] midiData0,
    output reg[6:0] midiData1
    );
    
    localparam ST_WAIT_COMMAND = 0;
    localparam ST_WAIT_DATA0   = 1;
    localparam ST_WAIT_DATA1   = 2;
    localparam ST_SEND_MSG     = 3;

    localparam CMD_NOTE_ON     = 3'h0;
    localparam CMD_NOTE_OFF    = 3'h1;
    localparam CMD_AFTERTOUCH  = 3'h2;
    localparam CMD_CC          = 3'h3;
    localparam CMD_PATCH_CHG   = 3'h4;
    localparam CMD_CH_PRESSURE = 3'h5;
    localparam CMD_PITCH_BEND  = 3'h6;
    localparam CMD_SYS         = 3'h7;
    
    reg[1:0] state, next_state;

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            state <= ST_WAIT_COMMAND;
        end
        else begin
            state <= next_state;
        end
    end

    
    always @(dataIn) begin
        cmd_ch_sysn = dataIn[3:0];
        cmd_proc    = 0;
        cmd_npar    = 0;
        cmd_type    = `MIDI_CMD_NONE;
        case (dataIn[6:4])
        3'h0: begin cmd_proc=1; cmd_npar=2; cmd_type=`MIDI_CMD_NOTE_ON    ; end
        3'h1: begin cmd_proc=1; cmd_npar=2; cmd_type=`MIDI_CMD_NOTE_OFF   ; end
        3'h2: begin cmd_proc=1; cmd_npar=2; cmd_type=`MIDI_CMD_AFTERTOUCH ; end
        3'h3: begin cmd_proc=1; cmd_npar=2; cmd_type=`MIDI_CMD_CC         ; end
        3'h4: begin cmd_proc=1; cmd_npar=2; cmd_type=`MIDI_CMD_PATCH_CHG  ; end
        3'h5: begin cmd_proc=1; cmd_npar=1; cmd_type=`MIDI_CMD_CH_PRESSURE; end
        3'h6: begin cmd_proc=1; cmd_npar=2; cmd_type=`MIDI_CMD_PITCH_BEND ; end
        3'h7: begin
            case (dataIn[3:0])
            4'h0: begin cmd_proc=0; cmd_npar=0; cmd_type=`MIDI_CMD_SYS_EXCL_ST   ; end
            4'h1: begin cmd_proc=1; cmd_npar=2; cmd_type=`MIDI_CMD_SYS_TIME_QF   ; end
            4'h2: begin cmd_proc=1; cmd_npar=2; cmd_type=`MIDI_CMD_SYS_SONG_POS  ; end
            4'h3: begin cmd_proc=1; cmd_npar=2; cmd_type=`MIDI_CMD_SYS_SONG_SEL  ; end
          //4'h4: begin cmd_proc=0; cmd_npar=2; cmd_type=`MIDI_CMD_NONE          ; end
          //4'h5: begin cmd_proc=0; cmd_npar=2; cmd_type=`MIDI_CMD_NONE          ; end
            4'h6: begin cmd_proc=0; cmd_npar=2; cmd_type=`MIDI_CMD_SYS_TUNE_REQ  ; end
            4'h7: begin cmd_proc=0; cmd_npar=0; cmd_type=`MIDI_CMD_SYS_EXCL_END  ; end
            4'h8: begin cmd_proc=1; cmd_npar=2; cmd_type=`MIDI_CMD_SYS_TIMING_CLK; end
          //4'h9: begin cmd_proc=0; cmd_npar=2; cmd_type=`MIDI_CMD_NONE          ; end
            4'ha: begin cmd_proc=1; cmd_npar=2; cmd_type=`MIDI_CMD_SYS_START     ; end
            4'hb: begin cmd_proc=1; cmd_npar=2; cmd_type=`MIDI_CMD_SYS_CONT      ; end
            4'hc: begin cmd_proc=1; cmd_npar=2; cmd_type=`MIDI_CMD_SYS_STOP      ; end
          //4'hd: begin cmd_proc=0; cmd_npar=2; cmd_type=`MIDI_CMD_NONE          ; end
            4'he: begin cmd_proc=0; cmd_npar=2; cmd_type=`MIDI_CMD_SYS_ACT_SNS   ; end
            4'hf: begin cmd_proc=1; cmd_npar=2; cmd_type=`MIDI_CMD_SYS_RST       ; end
            endcase
        end
        endcase
    end


    always @(*) begin
        next_state = state;
        case (state)
            ST_WAIT_COMMAND: begin
                if (dataInReady && dataIn[7]) begin
                    state <= ST_WAIT_DATA0;
                end
            end
            ST_WAIT_DATA0: begin
                if (dataInReady) begin
                    state <= !dataIn[7] ? ST_WAIT_DATA1 : ST_WAIT_COMMAND;
                end
            end
            ST_WAIT_DATA1: begin
                if (dataInReady) begin
                    state <= !dataIn[7] ? ST_SEND_MSG : ST_WAIT_COMMAND;
                end
            end
            ST_SEND_MSG: begin
                if (wbm_ack) begin
                    state <= ST_WAIT_COMMAND;
                end
            end
            default: begin
                state <= ST_WAIT_COMMAND;
            end
        endcase
    end



    always @(posedge reset or posedge clk) begin
        if (reset) begin
            midiCommand <= 0;
            midiChannel <= 0;
            midiData0   <= 0;
            midiData1   <= 0;
        end
        else if (dataInReady) begin 
            case (state) 
                ST_WAIT_COMMAND: begin
                    midiCommand <= dataIn[6:4];
                    midiChannel <= dataIn[3:0];
                end
                ST_WAIT_DATA0: begin
                    midiData0 <= dataIn[6:0];
                end
                ST_WAIT_DATA1: begin
                    midiData1 <= dataIn[6:0];
                end
            endcase
        end
    end

                if (dataInReady & dataIn[7]) begin
                    state <= ST_WAIT_DATA0;
                end
            end
            ST_WAIT_DATA0: begin
                if (dataInReady & !dataIn[7]) begin
                    state <= ST_WAIT_DATA1;
                end
                else if (dataInReady) begin
                    state <= ST_WAIT_COMMAND;
                end
            end
            ST_WAIT_DATA1: begin
                if (dataInReady & !dataIn[7]) begin
                    midiReady <= 1;
                end
                else if (dataInReady) begin
                    state <= ST_WAIT_COMMAND;
                end
            end
            default: begin
                state <= ST_WAIT_COMMAND;
            end





    /*
    wire is_first_level;

    always @(dataIn) begin
        case (dataIn[7:4])
        endcase
    end
    */


endmodule
