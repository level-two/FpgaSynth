// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: gen_sine.v
// Description: Simple sine generator
// -----------------------------------------------------------------------------

`include "globals.vh"

module gen_sine (
    input                       clk           ,
    input                       reset         ,

    input                       midi_rdy      ,
    input  [`MIDI_CMD_SIZE-1:0] midi_cmd      ,
    input  [3:0]                midi_ch_sysn  ,
    input  [6:0]                midi_data0    ,
    input  [6:0]                midi_data1    ,

    input                       smp_trig      ,
    output reg                  smp_out_rdy   ,
    output reg signed [17:0]    smp_out_l     ,
    output reg signed [17:0]    smp_out_r     ,

    // ALU
    output                      alu_cycle     ,
    output                      alu_strobe    ,
    input                       alu_ack       ,
    input                       alu_stall     ,
    //input                     alu_err       , // TBI

    output reg        [ 8:0]    alu_op        ,
    output reg signed [17:0]    alu_al        ,
    output reg signed [17:0]    alu_bl        ,
    output reg signed [47:0]    alu_cl        ,
    input      signed [47:0]    alu_pl        ,
    output reg signed [17:0]    alu_ar        ,
    output reg signed [17:0]    alu_br        ,
    output reg signed [47:0]    alu_cr        ,
    input      signed [47:0]    alu_pr        
);

    // TASKS
    localparam [15:0] NOP                      = 16'h0001;
    localparam [15:0] JP_0                     = 16'h0002;
    localparam [15:0] SEND_SMP                 = 16'h0004;
    localparam [15:0] SET_ALU_CYCLE            = 16'h0008;
    localparam [15:0] CLR_ALU_CYCLE            = 16'h0010;
    localparam [15:0] CALC_SIN_VAL             = 16'h0020;
    localparam [15:0] MUL_AC_AMPL              = 16'h0040;
    localparam [15:0] ADD_PHASE_STEP           = 16'h0080;
    localparam [15:0] MOV_PHASE_AC             = 16'h0100;
    localparam [15:0] MOV_SIN_VAL_AC           = 16'h0200;
    localparam [15:0] WAIT                     = 16'h0400;
    localparam [15:0] PI2_MINUS_AC             = 16'h0800;
    localparam [15:0] REACHED_MIN_BOUND        = 16'h1000;
    localparam [15:0] REACHED_MAX_BOUND        = 16'h2000;


    localparam [47:0] PI2    = {14'h0000, 18'h19220, 16'h0000}; // PI/2 constant
    localparam [17:0] PLUS1  = 18'h10000; // 1  constant
    localparam [17:0] MINUS1 = 18'h30000; // -1 constant

    localparam DIR_POS = 1'b1;
    localparam DIR_NEG = 1'b0;
    localparam SGN_POS = 1'b1;
    localparam SGN_NEG = 1'b0;


    wire note_on_event  = (midi_rdy && midi_cmd == `MIDI_CMD_NOTE_ON);
    wire note_off_event = (midi_rdy && midi_cmd == `MIDI_CMD_NOTE_OFF);

    reg [6:0] note;
    reg [6:0] ampl;
    reg note_on;

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            note    <= 7'h0;
            ampl    <= 7'h0;
            note_on <= 1'b0;
        end
        else if (note_off_event) begin
            note    <= 7'h0;
            ampl    <= 7'h0;
            note_on <= 1'b0;
        end
        else if (note_on_event) begin
            note    <= midi_data0;
            ampl    <= midi_data1;
            note_on <= 1'b1;
        end
    end


    reg [15:0] tasks;
    always @(pc) begin
        case (pc)
            4'h0   : tasks = (note_on     == 1'b0) ? WAIT ; NOP                ;
            4'h1   : tasks = (smp_trig    == 1'b0) ? WAIT ; SEND_SMP | SET_ALU_CYCLE;
            4'h2   : tasks = CALC_SIN_VAL                                      ;
            4'h3   : tasks = (alu_ack == 1'b0) ? WAIT : MUL_AC_AMPL            ;
            4'h4   : tasks = ADD_PHASE_STEP                                    ;
            4'h5   : tasks = (alu_ack == 1'b0) ? WAIT : MOV_SIN_VAL_AC         ;
            4'h5   : tasks = (alu_ack == 1'b0) ? WAIT                          :
                                 MOV_PHASE_AC                                  |
                                 (dir == DIR_NEG && alu_pl[47] == 1'b1)        ?
                                     REACHED_MIN_BOUND | CLR_ALU_CYCLE | JP_0  :
                                     PI2_MINUS_AC                              ;
            4'h5   : tasks = (alu_ack == 1'b0) ? WAIT                          :
                                 (alu_pl[47] == 1'b1 ? REACHED_MAX_BOUND : NOP)|
                                 CLR_ALU_CYCLE                                 |
                                 JP_0                                          ;
            default: tasks = JP_0                                              ;
        endcase
    end


    // PC
    reg [3:0] pc;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            pc <= 4'h0;
        end else if (tasks & JP_0) begin
            pc <= 4'h0;
        end else if (tasks & WAIT) begin
            pc <= pc;
        end else begin
            pc <= pc + 4'h1;
        end
    end


    // CYCLE
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            alu_cycle <= 1'b0;
        end else if (tasks & SET_ALU_CYCLE) begin
            alu_cycle <= 1'b1;
        end else if (tasks & CLR_ALU_CYCLE) begin
            alu_cycle <= 1'b0;
        end
    end


    // DIR/SIGN
    reg dir;
    reg sign;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            dir  <= DIR_POS;
            sign <= SGN_POS;
        end else if (tasks & REACHED_MIN_BOUND) begin
            dir  <= DIR_POS;
            sign <= ~sign;
        end else if (tasks & REACHED_MAX_BOUND) begin
            dir  <= DIR_NEG;
        end
    end


    reg [17:0] phase;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            phase <= 18'h00000;
        end else if (tasks & REACHED_MIN_BOUND) begin
            phase <= 18'h00000;
        end else if (tasks & REACHED_MAX_BOUND) begin
            phase <= PI2[33:16];
        end else if (tasks & MOV_PHASE_AC) begin
            phase <= alu_pl[33:16];
        end
    end


    reg [17:0] sin_val;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            sin_val <= 18'h00000;
        end else if (tasks & MOV_SIN_VAL_AC) begin
            sin_val <= alu_pl[33:16];
        end
    end


    always @(posedge reset or posedge clk) begin
        if (reset) begin
            smp_out_rdy <= 1'b0;
            smp_out_l   <= 18'h00000;
            smp_out_r   <= 18'h00000;
        end else if (tasks & SEND_SMP) begin
            smp_out_rdy <= 1'b1;
            smp_out_l   <= sin_val;
            smp_out_r   <= sin_val;
        end else begin
            smp_out_rdy <= 1'b0;
        end
    end


    always @(posedge reset or posedge clk) begin
        if (reset) begin
            alu_strobe <= 1'b0;
            alu_op <= `ALU_NOP;
            alu_al <= 18'h00000;
            alu_bl <= 18'h00000;
            alu_cl <= 48'h00000;
            alu_ar <= 18'h00000;
            alu_br <= 18'h00000;
            alu_cr <= 48'h00000;
        end
        else if (tasks & CALC_SIN_VAL) begin
            alu_strobe <= 1'b1;
            alu_op <= `ALU_FUNC_SIN;
            alu_al <= phase;
            alu_ar <= phase;
        end
        else if (tasks & MUL_AC_AMPL) begin
            alu_strobe <= 1'b1;
            alu_op <= `ALU_DSP_XIN_MULT | `ALU_DSP_ZIN_ZERO;
            alu_al <= alu_pl[33:16];
            alu_bl <= {2'b0, ampl[6:0], 9'h0};
            alu_ar <= alu_pr[33:16];
            alu_br <= {2'b0, ampl[6:0], 9'h0};
        end
        else if (tasks & ADD_PHASE_STEP) begin
            // phase+-step*sign
            alu_strobe <= 1'b1;
            alu_op <= `ALU_DSP_XIN_MULT |
                      `ALU_DSP_ZIN_CIN  |
                      (dir == DIR_POS ? `ALU_DSP_POSTADD_ADD : `ALU_DSP_POSTADD_SUB);
            alu_al <= step;
            alu_bl <= (sign == SGN_POS ? PLUS1 : MINUS1);
            alu_cl <= phase;
            alu_ar <= step;
            alu_br <= (sign == SGN_POS ? PLUS1 : MINUS1);
            alu_cr <= phase;
        end
        else if (tasks & PI2_MINUS_AC) begin
            alu_strobe <= 1'b1;
            alu_op <= `ALU_DSP_XIN_MULT   |
                      `ALU_DSP_ZIN_CIN    |
                      `ALU_DSP_POSTADD_SUB;
            alu_al <= alu_pl[33:16];
            alu_bl <= PLUS1;
            alu_cl <= PI2;
            alu_ar <= alu_pr[33:16];
            alu_br <= PLUS1;
            alu_cr <= PI2;
        end
        else begin
            alu_strobe <= 1'b0;
            alu_op <= `ALU_NOP;
            alu_al <= 18'h00000;
            alu_bl <= 18'h00000;
            alu_cl <= 48'h00000;
            alu_ar <= 18'h00000;
            alu_br <= 18'h00000;
            alu_cr <= 48'h00000;
        end
    end


    reg [17:0] step;
    always @(note) begin
        case (note)
            7'h00:   begin step <= 18'h00000; end
            7'h01:   begin step <= 18'h00000; end
            7'h02:   begin step <= 18'h00000; end
            7'h03:   begin step <= 18'h00000; end
            7'h04:   begin step <= 18'h00000; end
            7'h05:   begin step <= 18'h00000; end
            7'h06:   begin step <= 18'h00000; end
            7'h07:   begin step <= 18'h00000; end

            7'h08:   begin step <= 18'h00000; end
            7'h09:   begin step <= 18'h00000; end
            7'h0a:   begin step <= 18'h00000; end
            7'h0b:   begin step <= 18'h00000; end
            7'h0c:   begin step <= 18'h00000; end
            7'h0d:   begin step <= 18'h00000; end
            7'h0e:   begin step <= 18'h00000; end
            7'h0f:   begin step <= 18'h00000; end

            7'h10:   begin step <= 18'h00000; end
            7'h11:   begin step <= 18'h00000; end
            7'h12:   begin step <= 18'h00000; end
            7'h13:   begin step <= 18'h00000; end
            7'h14:   begin step <= 18'h00000; end
            7'h15:   begin step <= 18'h00000; end
            7'h16:   begin step <= 18'h00000; end
            7'h17:   begin step <= 18'h00000; end

            7'h18:   begin step <= 18'h00000; end
            7'h19:   begin step <= 18'h00000; end
            7'h1a:   begin step <= 18'h00000; end
            7'h1b:   begin step <= 18'h00000; end
            7'h1c:   begin step <= 18'h00000; end
            7'h1d:   begin step <= 18'h00000; end
            7'h1e:   begin step <= 18'h00000; end
            7'h1f:   begin step <= 18'h00000; end

            7'h20:   begin step <= 18'h01111; end
            7'h21:   begin step <= 18'h00000; end
            7'h22:   begin step <= 18'h00000; end
            7'h23:   begin step <= 18'h00000; end
            7'h24:   begin step <= 18'h00000; end
            7'h25:   begin step <= 18'h00000; end
            7'h26:   begin step <= 18'h00000; end
            7'h27:   begin step <= 18'h00000; end

            7'h28:   begin step <= 18'h00000; end
            7'h29:   begin step <= 18'h00000; end
            7'h2a:   begin step <= 18'h00000; end
            7'h2b:   begin step <= 18'h00000; end
            7'h2c:   begin step <= 18'h00000; end
            7'h2d:   begin step <= 18'h00000; end
            7'h2e:   begin step <= 18'h00000; end
            7'h2f:   begin step <= 18'h00000; end

            7'h30:   begin step <= 18'h00000; end
            7'h31:   begin step <= 18'h00000; end
            7'h32:   begin step <= 18'h00000; end
            7'h33:   begin step <= 18'h00000; end
            7'h34:   begin step <= 18'h00000; end
            7'h35:   begin step <= 18'h00000; end
            7'h36:   begin step <= 18'h00000; end
            7'h37:   begin step <= 18'h00000; end

            7'h38:   begin step <= 18'h00000; end
            7'h39:   begin step <= 18'h00000; end
            7'h3a:   begin step <= 18'h00000; end
            7'h3b:   begin step <= 18'h00000; end
            7'h3c:   begin step <= 18'h00000; end
            7'h3d:   begin step <= 18'h00000; end
            7'h3e:   begin step <= 18'h00000; end
            7'h3f:   begin step <= 18'h00000; end

            7'h40:   begin step <= 18'h00000; end
            7'h41:   begin step <= 18'h00000; end
            7'h42:   begin step <= 18'h00000; end
            7'h43:   begin step <= 18'h00000; end
            7'h44:   begin step <= 18'h00000; end
            7'h45:   begin step <= 18'h00000; end
            7'h46:   begin step <= 18'h00000; end
            7'h47:   begin step <= 18'h00000; end

            7'h48:   begin step <= 18'h00000; end
            7'h49:   begin step <= 18'h00000; end
            7'h4a:   begin step <= 18'h00000; end
            7'h4b:   begin step <= 18'h00000; end
            7'h4c:   begin step <= 18'h00000; end
            7'h4d:   begin step <= 18'h00000; end
            7'h4e:   begin step <= 18'h00000; end
            7'h4f:   begin step <= 18'h00000; end

            7'h50:   begin step <= 18'h00000; end
            7'h51:   begin step <= 18'h00000; end
            7'h52:   begin step <= 18'h00000; end
            7'h53:   begin step <= 18'h00000; end
            7'h54:   begin step <= 18'h00000; end
            7'h55:   begin step <= 18'h00000; end
            7'h56:   begin step <= 18'h00000; end
            7'h57:   begin step <= 18'h00000; end

            7'h58:   begin step <= 18'h00000; end
            7'h59:   begin step <= 18'h00000; end
            7'h5a:   begin step <= 18'h00000; end
            7'h5b:   begin step <= 18'h00000; end
            7'h5c:   begin step <= 18'h00000; end
            7'h5d:   begin step <= 18'h00000; end
            7'h5e:   begin step <= 18'h00000; end
            7'h5f:   begin step <= 18'h00000; end

            7'h60:   begin step <= 18'h00000; end
            7'h61:   begin step <= 18'h00000; end
            7'h62:   begin step <= 18'h00000; end
            7'h63:   begin step <= 18'h00000; end
            7'h64:   begin step <= 18'h00000; end
            7'h65:   begin step <= 18'h00000; end
            7'h66:   begin step <= 18'h00000; end
            7'h67:   begin step <= 18'h00000; end

            7'h68:   begin step <= 18'h00000; end
            7'h69:   begin step <= 18'h00000; end
            7'h6a:   begin step <= 18'h00000; end
            7'h6b:   begin step <= 18'h00000; end
            7'h6c:   begin step <= 18'h00000; end
            7'h6d:   begin step <= 18'h00000; end
            7'h6e:   begin step <= 18'h00000; end
            7'h6f:   begin step <= 18'h00000; end

            7'h70:   begin step <= 18'h00000; end
            7'h71:   begin step <= 18'h00000; end
            7'h72:   begin step <= 18'h00000; end
            7'h73:   begin step <= 18'h00000; end
            7'h74:   begin step <= 18'h00000; end
            7'h75:   begin step <= 18'h00000; end
            7'h76:   begin step <= 18'h00000; end
            7'h77:   begin step <= 18'h00000; end

            7'h78:   begin step <= 18'h00000; end
            7'h79:   begin step <= 18'h00000; end
            7'h7a:   begin step <= 18'h00000; end
            7'h7b:   begin step <= 18'h00000; end
            7'h7c:   begin step <= 18'h00000; end
            7'h7d:   begin step <= 18'h00000; end
            7'h7e:   begin step <= 18'h00000; end
            7'h7f:   begin step <= 18'h00000; end
            default: begin step <= 18'h00000; end
        endcase
    end
endmodule
