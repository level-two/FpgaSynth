// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: gen_pulse.v
// Description: Simple pulse generator
// -----------------------------------------------------------------------------

`include "globals.vh"

module gen_pulse (
    input                       clk,
    input                       reset,
    input                       midi_rdy,
    input  [`MIDI_CMD_SIZE-1:0] midi_cmd,
    input  [3:0]                midi_ch_sysn,
    input  [6:0]                midi_data0,
    input  [6:0]                midi_data1,
    input                       sample_rate_8x_trig,
    output                      sample_out_rdy,
    output signed [17:0]        sample_out_l,
    output signed [17:0]        sample_out_r,

    input  [47:0]               dsp_outs_flat_l,
    input  [47:0]               dsp_outs_flat_r,
    output [91:0]               dsp_ins_flat_l,
    output [91:0]               dsp_ins_flat_r
);


    // TASKS
    localparam [15:0] NOP              = 16'h0000;
    localparam [15:0] MOV_I_0          = 16'h0001;
    localparam [15:0] INC_I            = 16'h0002;
    localparam [15:0] DEC_I            = 16'h0004;
    localparam [15:0] MAC_AI_AMPL      = 16'h0008;
    localparam [15:0] MAC_1_AMPL       = 16'h0010;
    localparam [15:0] MAC_AI_AMPL_N    = 16'h0020;
    localparam [15:0] MAC_1_AMPL_N     = 16'h0040;
    localparam [15:0] WAIT_SAMPLE_TRIG = 16'h0080;
    localparam [15:0] MOV_FIR_AC       = 16'h0100;
    localparam [15:0] MAC_AI_AMPL      = 16'h0200;
    localparam [15:0] REPEAT_8         = 16'h0400;
    localparam [15:0] JP_UP_2          = 16'h0800;
    localparam [15:0] JP_0             = 16'h1000;


    reg [15:0] tasks;
    always @(pc) begin
        case (pc)
            5'h0   : tasks = MOV_I_0                |
                             ((note_on == 1'b0) ? JP_0 : NOP);

            // 0 => 1
            5'h1   : tasks = WAIT_SAMPLE_TRIG       ;
            5'h2   : tasks = REPEAT_8               |
                             MAC_AI_AMPL            |
                             MOV_FIR_AC             |
                             INC_I                  ;
            5'h3   : tasks = (i_reg[6] == 1'b0) ? JP_UP_2 : NOP;

            // 1
            5'h4   : tasks = WAIT_SAMPLE_TRIG       ;
            5'h5   : tasks = REPEAT_8               |
                             MAC_1_AMPL             |
                             MOV_FIR_AC             ;
            5'h6   : tasks = (divider_cnt_event == 1'b0) ? JP_UP_2 : NOP;

            // 1 => 0
            5'h7   : tasks = WAIT_SAMPLE_TRIG       ;
            5'h8   : tasks = REPEAT_8               |
                             MAC_AI_AMPL            |
                             MOV_FIR_AC             |
                             DEC_I                  ;
            5'h9   : tasks = (|i_reg != 1'b0) ? JP_UP_2 : NOP;
            //

            // 0 => -1
            5'ha   : tasks = WAIT_SAMPLE_TRIG       ;
            5'hb   : tasks = REPEAT_8               |
                             MAC_AI_AMPL_N          |
                             MOV_FIR_AC             |
                             INC_I                  ;
            5'hc   : tasks = (i_reg[6] == 1'b0) ? JP_UP_2 : NOP;

            // -1
            5'hd   : tasks = WAIT_SAMPLE_TRIG       ;
            5'he   : tasks = REPEAT_8               |
                             MAC_1_AMPL_N           |
                             MOV_FIR_AC             ;
            5'hf   : tasks = (divider_cnt_event == 1'b0) ? JP_UP_2 : NOP;

            // -1 => 0
            5'h10  : tasks = WAIT_SAMPLE_TRIG       ;
            5'h11  : tasks = REPEAT_8               |
                             MAC_AI_AMPL_N          |
                             MOV_FIR_AC             |
                             DEC_I                  ;
            5'h12  : tasks = (|i_reg != 1'b0) ? JP_UP_2 : JP_0;

            default: tasks = JP_0                   ;
        endcase
    end


    // PC
    reg [4:0] pc;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            pc <= 5'h0;
        end
        else if (tasks & JP_0) begin
            pc <= 5'h0;
        end
        else if (tasks & JP_UP_2) begin
            pc <= pc - 5'h2;
        end
        else if ((tasks & WAIT_SAMPLE_TRIG && !sample_rate_8x_trig) ||
                 (tasks & REPEAT_8         && repeat_st           )) begin
            pc <= pc;
        end
        else begin
            pc <= pc + 5'h1;
        end
    end


    // REPEAT
    reg  [2:0] repeat_cnt;
    wire [2:0] repeat_cnt_max = (tasks & REPEAT_8) ? 'h7 : 'h0;
    wire repeat_st = (repeat_cnt != repeat_cnt_max);

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            repeat_cnt <= 'h0;
        end
        else if (repeat_cnt == repeat_cnt_max) begin
            repeat_cnt <= 'h0;
        end
        else begin
            repeat_cnt <= repeat_cnt + 'h1;
        end
    end


    // INDEX REGISTER I
    reg  [6:0] i_reg;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            i_reg <= 'h0;
        end
        else if (tasks & MOV_I_0) begin
            i_reg <= 'h0;
        end
        else if (tasks & INC_I) begin
            i_reg <= i_reg + 'h1;
        end
        else if (tasks & DEC_I) begin
            i_reg <= i_reg - 'h1;
        end
    end



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


    reg  [23:0] divider_cnt;
    wire        divider_cnt_evnt = (divider_cnt == div);
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            divider_cnt <= 0;
        end
        else if (divider_cnt == div) || note_on_event || note_off_event) begin
            divider_cnt <= 0;
        end
        else begin
            divider_cnt <= divider_cnt + 1;
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
        else if (divider_cnt_evnt) begin
            sample_val <= -sample_val;
        end
    end



    // Decimating filter
    wire               fir_sample_in_rdy = sample_rate_8x_trig;
    wire signed [17:0] fir_sample_in_l   = cur_val;
    wire signed [17:0] fir_sample_in_r   = cur_val;

    wire               fir_sample_out_rdy;
    wire signed [17:0] fir_sample_out_l;
    wire signed [17:0] fir_sample_out_r;

    fir_decim_384k_48k  fir_decim_384k_48k (
        .clk              (clk                 ),
        .reset            (reset               ),
        .sample_in_rdy    (fir_sample_in_rdy   ),
        .sample_in_l      (fir_sample_in_l     ),
        .sample_in_r      (fir_sample_in_r     ),
        .sample_out_rdy   (fir_sample_out_rdy  ),
        .sample_out_l     (fir_sample_out_l    ),
        .sample_out_r     (fir_sample_out_r    ),
        .dsp_outs_flat_l  (dsp_outs_flat_l     ),
        .dsp_outs_flat_r  (dsp_outs_flat_r     ),
        .dsp_ins_flat_l   (dsp_ins_flat_l      ),
        .dsp_ins_flat_r   (dsp_ins_flat_r      )
    );

    // Outs
    assign sample_out_rdy = fir_sample_out_rdy;
    assign sample_out_l   = fir_sample_out_l;
    assign sample_out_r   = fir_sample_out_r;


    reg [23:0] div;
    always @(note) begin
        case (note)
            7'h00:   begin div <= 24'h5d5084; end
            7'h01:   begin div <= 24'h5813c2; end
            7'h02:   begin div <= 24'h532240; end
            7'h03:   begin div <= 24'h4e77c5; end
            7'h04:   begin div <= 24'h4a1054; end
            7'h05:   begin div <= 24'h45e82b; end
            7'h06:   begin div <= 24'h41fbbc; end
            7'h07:   begin div <= 24'h3e47ac; end

            7'h08:   begin div <= 24'h3ac8d3; end
            7'h09:   begin div <= 24'h377c32; end
            7'h0a:   begin div <= 24'h345efa; end
            7'h0b:   begin div <= 24'h316e80; end
            7'h0c:   begin div <= 24'h2ea842; end
            7'h0d:   begin div <= 24'h2c09e1; end
            7'h0e:   begin div <= 24'h299120; end
            7'h0f:   begin div <= 24'h273be2; end

            7'h10:   begin div <= 24'h25082a; end
            7'h11:   begin div <= 24'h22f415; end
            7'h12:   begin div <= 24'h20fdde; end
            7'h13:   begin div <= 24'h1f23d6; end
            7'h14:   begin div <= 24'h1d6469; end
            7'h15:   begin div <= 24'h1bbe19; end
            7'h16:   begin div <= 24'h1a2f7d; end
            7'h17:   begin div <= 24'h18b740; end

            7'h18:   begin div <= 24'h175421; end
            7'h19:   begin div <= 24'h1604f1; end
            7'h1a:   begin div <= 24'h14c890; end
            7'h1b:   begin div <= 24'h139df1; end
            7'h1c:   begin div <= 24'h128415; end
            7'h1d:   begin div <= 24'h117a0b; end
            7'h1e:   begin div <= 24'h107eef; end
            7'h1f:   begin div <= 24'h0f91eb; end

            7'h20:   begin div <= 24'h0eb235; end
            7'h21:   begin div <= 24'h0ddf0d; end
            7'h22:   begin div <= 24'h0d17bf; end
            7'h23:   begin div <= 24'h0c5ba0; end
            7'h24:   begin div <= 24'h0baa11; end
            7'h25:   begin div <= 24'h0b0278; end
            7'h26:   begin div <= 24'h0a6448; end
            7'h27:   begin div <= 24'h09cef9; end

            7'h28:   begin div <= 24'h09420b; end
            7'h29:   begin div <= 24'h08bd05; end
            7'h2a:   begin div <= 24'h083f77; end
            7'h2b:   begin div <= 24'h07c8f6; end
            7'h2c:   begin div <= 24'h07591a; end
            7'h2d:   begin div <= 24'h06ef86; end
            7'h2e:   begin div <= 24'h068bdf; end
            7'h2f:   begin div <= 24'h062dd0; end

            7'h30:   begin div <= 24'h05d508; end
            7'h31:   begin div <= 24'h05813c; end
            7'h32:   begin div <= 24'h053224; end
            7'h33:   begin div <= 24'h04e77c; end
            7'h34:   begin div <= 24'h04a105; end
            7'h35:   begin div <= 24'h045e83; end
            7'h36:   begin div <= 24'h041fbc; end
            7'h37:   begin div <= 24'h03e47b; end

            7'h38:   begin div <= 24'h03ac8d; end
            7'h39:   begin div <= 24'h0377c3; end
            7'h3a:   begin div <= 24'h0345f0; end
            7'h3b:   begin div <= 24'h0316e8; end
            7'h3c:   begin div <= 24'h02ea84; end
            7'h3d:   begin div <= 24'h02c09e; end
            7'h3e:   begin div <= 24'h029912; end
            7'h3f:   begin div <= 24'h0273be; end

            7'h40:   begin div <= 24'h025083; end
            7'h41:   begin div <= 24'h022f41; end
            7'h42:   begin div <= 24'h020fde; end
            7'h43:   begin div <= 24'h01f23d; end
            7'h44:   begin div <= 24'h01d647; end
            7'h45:   begin div <= 24'h01bbe2; end
            7'h46:   begin div <= 24'h01a2f8; end
            7'h47:   begin div <= 24'h018b74; end

            7'h48:   begin div <= 24'h017542; end
            7'h49:   begin div <= 24'h01604f; end
            7'h4a:   begin div <= 24'h014c89; end
            7'h4b:   begin div <= 24'h0139df; end
            7'h4c:   begin div <= 24'h012841; end
            7'h4d:   begin div <= 24'h0117a1; end
            7'h4e:   begin div <= 24'h0107ef; end
            7'h4f:   begin div <= 24'h00f91f; end

            7'h50:   begin div <= 24'h00eb23; end
            7'h51:   begin div <= 24'h00ddf1; end
            7'h52:   begin div <= 24'h00d17c; end
            7'h53:   begin div <= 24'h00c5ba; end
            7'h54:   begin div <= 24'h00baa1; end
            7'h55:   begin div <= 24'h00b028; end
            7'h56:   begin div <= 24'h00a645; end
            7'h57:   begin div <= 24'h009cf0; end

            7'h58:   begin div <= 24'h009421; end
            7'h59:   begin div <= 24'h008bd0; end
            7'h5a:   begin div <= 24'h0083f7; end
            7'h5b:   begin div <= 24'h007c8f; end
            7'h5c:   begin div <= 24'h007592; end
            7'h5d:   begin div <= 24'h006ef8; end
            7'h5e:   begin div <= 24'h0068be; end
            7'h5f:   begin div <= 24'h0062dd; end

            7'h60:   begin div <= 24'h005d51; end
            7'h61:   begin div <= 24'h005814; end
            7'h62:   begin div <= 24'h005322; end
            7'h63:   begin div <= 24'h004e78; end
            7'h64:   begin div <= 24'h004a10; end
            7'h65:   begin div <= 24'h0045e8; end
            7'h66:   begin div <= 24'h0041fc; end
            7'h67:   begin div <= 24'h003e48; end

            7'h68:   begin div <= 24'h003ac9; end
            7'h69:   begin div <= 24'h00377c; end
            7'h6a:   begin div <= 24'h00345f; end
            7'h6b:   begin div <= 24'h00316e; end
            7'h6c:   begin div <= 24'h002ea8; end
            7'h6d:   begin div <= 24'h002c0a; end
            7'h6e:   begin div <= 24'h002991; end
            7'h6f:   begin div <= 24'h00273c; end

            7'h70:   begin div <= 24'h002508; end
            7'h71:   begin div <= 24'h0022f4; end
            7'h72:   begin div <= 24'h0020fe; end
            7'h73:   begin div <= 24'h001f24; end
            7'h74:   begin div <= 24'h001d64; end
            7'h75:   begin div <= 24'h001bbe; end
            7'h76:   begin div <= 24'h001a2f; end
            7'h77:   begin div <= 24'h0018b7; end

            7'h78:   begin div <= 24'h001754; end
            7'h79:   begin div <= 24'h001605; end
            7'h7a:   begin div <= 24'h0014c9; end
            7'h7b:   begin div <= 24'h00139e; end
            7'h7c:   begin div <= 24'h001284; end
            7'h7d:   begin div <= 24'h00117a; end
            7'h7e:   begin div <= 24'h00107f; end
            7'h7f:   begin div <= 24'h000f92; end
            default: begin div <= 24'hffffff; end
        endcase
    end


    // Coefficients
    reg signed [17:0] ci;
    always @(i_reg) begin
        case (i_reg)
            'h0    : begin ci <= 18'h3FFFE; end
            'h1    : begin ci <= 18'h3FFFE; end
            'h2    : begin ci <= 18'h3FFFF; end
            'h3    : begin ci <= 18'h00006; end
            'h4    : begin ci <= 18'h00013; end
            'h5    : begin ci <= 18'h00027; end
            'h6    : begin ci <= 18'h00040; end
            'h7    : begin ci <= 18'h00058; end
            'h8    : begin ci <= 18'h00065; end
            'h9    : begin ci <= 18'h0005B; end
            'ha    : begin ci <= 18'h0002B; end
            'hb    : begin ci <= 18'h3FFCC; end
            'hc    : begin ci <= 18'h3FF3B; end
            'hd    : begin ci <= 18'h3FE82; end
            'he    : begin ci <= 18'h3FDBC; end
            'hf    : begin ci <= 18'h3FD13; end
            'h10   : begin ci <= 18'h3FCBE; end
            'h11   : begin ci <= 18'h3FCF9; end
            'h12   : begin ci <= 18'h3FDFF; end
            'h13   : begin ci <= 18'h3FFF7; end
            'h14   : begin ci <= 18'h002F0; end
            'h15   : begin ci <= 18'h006D5; end
            'h16   : begin ci <= 18'h00B6A; end
            'h17   : begin ci <= 18'h01054; end
            'h18   : begin ci <= 18'h0151B; end
            'h19   : begin ci <= 18'h01942; end
            'h1a   : begin ci <= 18'h01C54; end
            'h1b   : begin ci <= 18'h01DF5; end
            'h1c   : begin ci <= 18'h01DF5; end
            'h1d   : begin ci <= 18'h01C54; end
            'h1e   : begin ci <= 18'h01942; end
            'h1f   : begin ci <= 18'h0151B; end
            default: begin ci <= 18'h00000; end
        endcase
    end


    // MUL TASKS
    always @(*) begin
        opmode = `DSP_NOP;
        al     = 18'h00000;
        ar     = 18'h00000;
        bl     = 18'h00000;
        br     = 18'h00000;

        if (tasks & MAC_CI_XJ) begin
            opmode = `DSP_XIN_MULT | `DSP_ZIN_POUT;
            al     = ci;
            ar     = ci;
            bl     = xjl;
            br     = xjr;
        end
    end


    // DSP signals
    reg         [7:0]  opmode;
    reg  signed [17:0] al;
    reg  signed [17:0] ar;
    reg  signed [17:0] bl;
    reg  signed [17:0] br;
    wire signed [47:0] c_nc = 48'b0;
    wire signed [47:0] pl;
    wire signed [47:0] pr;

    // Gather local DSP signals 
    assign dsp_ins_flat_l[91:0] = {opmode, al, bl, c_nc};
    assign dsp_ins_flat_r[91:0] = {opmode, ar, br, c_nc};
    assign pl = dsp_outs_flat_l;
    assign pr = dsp_outs_flat_r;
endmodule
