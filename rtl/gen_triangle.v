// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: gen_triangle.v
// Description: Simple triangle generator
// -----------------------------------------------------------------------------

`include "globals.vh"

module gen_triangle (
    input                       clk,
    input                       reset,
    input                       midi_rdy,
    input  [`MIDI_CMD_SIZE-1:0] midi_cmd,
    input  [3:0]                midi_ch_sysn,
    input  [6:0]                midi_data0,
    input  [6:0]                midi_data1,
    input                       sample_rate_trig,
    output                      sample_out_rdy,
    output signed [17:0]        sample_out_l,
    output signed [17:0]        sample_out_r,

    input  [47:0]               dsp_outs_flat_l,
    input  [47:0]               dsp_outs_flat_r,
    output [91:0]               dsp_ins_flat_l,
    output [91:0]               dsp_ins_flat_r
);


    wire note_on_event  = (midi_rdy && midi_cmd == `MIDI_CMD_NOTE_ON);
    wire note_off_event = (midi_rdy && midi_cmd == `MIDI_CMD_NOTE_OFF);

    reg [6:0] note;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            note    <= 7'h0;
        end
        else if (note_on_event) begin
            note    <= midi_data0;
        end
    end





    ///
    // TASKS
    localparam [15:0] NOP               = 16'h0000;
    localparam [15:0] WAIT_IN           = 16'h0001;
    localparam [15:0] JP_0              = 16'h0002;
    localparam [15:0] ADD_SL_I1L        = 16'h0004;
    localparam [15:0] ADD_SR_I1R        = 16'h0008;
    localparam [15:0] ADD_DL            = 16'h0010;
    localparam [15:0] ADD_DR            = 16'h0020;
    localparam [15:0] ADD_I2L           = 16'h0040;
    localparam [15:0] ADD_I2R           = 16'h0080;
    localparam [15:0] MOV_I1L_ACC       = 16'h0100;
    localparam [15:0] MOV_I1R_ACC       = 16'h0200;
    localparam [15:0] MOV_I2L_ACC       = 16'h0400;
    localparam [15:0] MOV_I2R_ACC       = 16'h0800;
    localparam [15:0] MOV_DL_ACCSGN     = 16'h1000;
    localparam [15:0] MOV_DR_ACCSGN     = 16'h2000;
    localparam [15:0] MOV_OUTL_ACCSGN   = 16'h4000;
    localparam [15:0] MOV_OUTR_ACCSGN   = 16'h8000;
              
    reg [15:0] tasks;
    always @(pc) begin
        case (pc)
            4'h0   : tasks = WAIT_IN            ;
            // Left sample calc
            4'h1   : tasks = ADD_SL_I1L         ;
            4'h2   : tasks = ADD_DL             ;
            4'h3   : tasks = MOV_I1L_ACC        |
                             ADD_I2L            ;
            4'h4   : tasks = ADD_DL             ;
            4'h5   : tasks = MOV_DL_ACCSGN      |
                             MOV_I2L_ACC        |
                             MOV_OUTL_ACCSGN    |
            // Right sample calc
                             ADD_SR_I1R         ;
            4'h6   : tasks = ADD_DR             ;
            4'h7   : tasks = MOV_DR_ACCSGN      |
                             MOV_I1R_ACC        |
                             MOV_OUTR_ACCSGN    |
                             JP_0               ;
            default: tasks = JP_0               ;
        endcase
    end

    // PC
    wire [3:0] pc;
    task_pc #(
        .PC_W     (4),
        .TASKS_W  (16),
        .TASKS_JP ({ JP_0 , 0 ,
                     JP_11, 11,
                     NOP  , 0 ,
                     NOP  , 0 }),
        .TASK_JPS (JPS)
    ) tasks_pc_inst (
        .clk    (clk     ),
        .reset  (reset   ),
        .tasks  (tasks   ),
        .pc_out (pc      )
    );



































    reg dir;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            dir <= 1'b1;
        end
        else if (val[17:16] == 2'b01) begin
            dir <= 1'b0;
        end
        else if (val[17:16] == 2'b10) begin
            dir <= 1'b1;
        end
    end


    reg signed [17:0] val;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            val <= 18'h00000;
        end
        else if (sample_rate_trig && dir) begin
            val <= val + step;
        end
        else if (sample_rate_trig && ~dir) begin
            val <= val - step;
        end
    end



    reg signed [17:0] sample_val;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            sample_val <= 0;
        end
        else if (note_on_event) begin
            sample_val <= {2'b00, midi_data1, 9'b0};
        end
        else if (note_off_event) begin
            sample_val <= 0;
        end
        else if (stepider_cnt_evnt) begin
            sample_val <= -sample_val;
        end
    end


    reg signed [17:0] step;
    always @(note) begin
        case (note)
            7'h00:   begin step <= 18'h00059; end
            7'h01:   begin step <= 18'h0005E; end
            7'h02:   begin step <= 18'h00064; end
            7'h03:   begin step <= 18'h0006A; end
            7'h04:   begin step <= 18'h00070; end
            7'h05:   begin step <= 18'h00077; end
            7'h06:   begin step <= 18'h0007E; end
            7'h07:   begin step <= 18'h00085; end
            7'h08:   begin step <= 18'h0008D; end
            7'h09:   begin step <= 18'h00096; end
            7'h0a:   begin step <= 18'h0009F; end
            7'h0b:   begin step <= 18'h000A8; end
            7'h0c:   begin step <= 18'h000B2; end
            7'h0d:   begin step <= 18'h000BD; end
            7'h0e:   begin step <= 18'h000C8; end
            7'h0f:   begin step <= 18'h000D4; end
            7'h10:   begin step <= 18'h000E1; end
            7'h11:   begin step <= 18'h000EE; end
            7'h12:   begin step <= 18'h000FC; end
            7'h13:   begin step <= 18'h0010B; end
            7'h14:   begin step <= 18'h0011B; end
            7'h15:   begin step <= 18'h0012C; end
            7'h16:   begin step <= 18'h0013E; end
            7'h17:   begin step <= 18'h00151; end
            7'h18:   begin step <= 18'h00165; end
            7'h19:   begin step <= 18'h0017A; end
            7'h1a:   begin step <= 18'h00190; end
            7'h1b:   begin step <= 18'h001A8; end
            7'h1c:   begin step <= 18'h001C2; end
            7'h1d:   begin step <= 18'h001DC; end
            7'h1e:   begin step <= 18'h001F9; end
            7'h1f:   begin step <= 18'h00217; end
            7'h20:   begin step <= 18'h00237; end
            7'h21:   begin step <= 18'h00258; end
            7'h22:   begin step <= 18'h0027C; end
            7'h23:   begin step <= 18'h002A2; end
            7'h24:   begin step <= 18'h002CA; end
            7'h25:   begin step <= 18'h002F4; end
            7'h26:   begin step <= 18'h00321; end
            7'h27:   begin step <= 18'h00351; end
            7'h28:   begin step <= 18'h00384; end
            7'h29:   begin step <= 18'h003B9; end
            7'h2a:   begin step <= 18'h003F2; end
            7'h2b:   begin step <= 18'h0042E; end
            7'h2c:   begin step <= 18'h0046E; end
            7'h2d:   begin step <= 18'h004B1; end
            7'h2e:   begin step <= 18'h004F8; end
            7'h2f:   begin step <= 18'h00544; end
            7'h30:   begin step <= 18'h00594; end
            7'h31:   begin step <= 18'h005E9; end
            7'h32:   begin step <= 18'h00643; end
            7'h33:   begin step <= 18'h006A3; end
            7'h34:   begin step <= 18'h00708; end
            7'h35:   begin step <= 18'h00773; end
            7'h36:   begin step <= 18'h007E4; end
            7'h37:   begin step <= 18'h0085C; end
            7'h38:   begin step <= 18'h008DC; end
            7'h39:   begin step <= 18'h00962; end
            7'h3a:   begin step <= 18'h009F1; end
            7'h3b:   begin step <= 18'h00A89; end
            7'h3c:   begin step <= 18'h00B29; end
            7'h3d:   begin step <= 18'h00BD3; end
            7'h3e:   begin step <= 18'h00C87; end
            7'h3f:   begin step <= 18'h00D46; end
            7'h40:   begin step <= 18'h00E10; end
            7'h41:   begin step <= 18'h00EE6; end
            7'h42:   begin step <= 18'h00FC9; end
            7'h43:   begin step <= 18'h010B9; end
            7'h44:   begin step <= 18'h011B8; end
            7'h45:   begin step <= 18'h012C5; end
            7'h46:   begin step <= 18'h013E3; end
            7'h47:   begin step <= 18'h01512; end
            7'h48:   begin step <= 18'h01653; end
            7'h49:   begin step <= 18'h017A7; end
            7'h4a:   begin step <= 18'h0190F; end
            7'h4b:   begin step <= 18'h01A8C; end
            7'h4c:   begin step <= 18'h01C20; end
            7'h4d:   begin step <= 18'h01DCD; end
            7'h4e:   begin step <= 18'h01F92; end
            7'h4f:   begin step <= 18'h02173; end
            7'h50:   begin step <= 18'h02370; end
            7'h51:   begin step <= 18'h0258B; end
            7'h52:   begin step <= 18'h027C7; end
            7'h53:   begin step <= 18'h02A25; end
            7'h54:   begin step <= 18'h02CA6; end
            7'h55:   begin step <= 18'h02F4E; end
            7'h56:   begin step <= 18'h0321E; end
            7'h57:   begin step <= 18'h03519; end
            7'h58:   begin step <= 18'h03841; end
            7'h59:   begin step <= 18'h03B9A; end
            7'h5a:   begin step <= 18'h03F25; end
            7'h5b:   begin step <= 18'h042E6; end
            7'h5c:   begin step <= 18'h046E0; end
            7'h5d:   begin step <= 18'h04B17; end
            7'h5e:   begin step <= 18'h04F8F; end
            7'h5f:   begin step <= 18'h0544A; end
            7'h60:   begin step <= 18'h0594D; end
            7'h61:   begin step <= 18'h05E9C; end
            7'h62:   begin step <= 18'h0643C; end
            7'h63:   begin step <= 18'h06A32; end
            default: begin step <= 18'h06A32; end
        endcase
    end
endmodule
