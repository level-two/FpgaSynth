// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: fir_interp_20k_192k_8x.v
// Description: Interpolating FIR
//              Fs_in  =  192 kHz
//              Fs_out = 1536 kHz
//              Fpass  =   20 kHz
//              k      =    8
// -----------------------------------------------------------------------------

`include "globals.vh"

module fir_interp_20k_192k_8x (
    input                    clk,
    input                    reset,

    input                    sample_in_rdy,
    input  signed [17:0]     sample_in_l,
    input  signed [17:0]     sample_in_r,

    output reg               sample_out_rdy,
    output reg signed [17:0] sample_out_l,
    output reg signed [17:0] sample_out_r,
    output reg               done,

    input  [47:0]            dsp_outs_flat_l,
    input  [47:0]            dsp_outs_flat_r,
    output [91:0]            dsp_ins_flat_l,
    output [91:0]            dsp_ins_flat_r
);

    // STORE SAMPLE_IN
    reg signed [17:0] sample_in_reg_l;
    reg signed [17:0] sample_in_reg_r;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            sample_in_reg_l <= 18'h00000;
            sample_in_reg_r <= 18'h00000;
        end
        else if (sample_in_rdy) begin
            sample_in_reg_l <= sample_in_l;
            sample_in_reg_r <= sample_in_r;
        end
    end


    // TASKS
    localparam [15:0] NOP              = 16'h0000;
    localparam [15:0] WAIT_IN          = 16'h0001;
    localparam [15:0] MOV_I_0          = 16'h0002;
    localparam [15:0] INC_I            = 16'h0004;
    localparam [15:0] MOV_J_0          = 16'h0008;
    localparam [15:0] INC_J            = 16'h0010;
    localparam [15:0] MOV_IX_XHEAD     = 16'h0020;
    localparam [15:0] INC_IX_CIRC      = 16'h0040;
    localparam [15:0] PUSH_X           = 16'h0080;
    localparam [15:0] MAC_CIJ_X        = 16'h0100;
    localparam [15:0] MOV_RES_AC       = 16'h0200;
    localparam [15:0] REPEAT_7         = 16'h0400;
    localparam [15:0] JP_1             = 16'h0800;
    localparam [15:0] JP_3             = 16'h1000;
    localparam [15:0] DONE             = 16'h2000;

    reg [15:0] tasks;
    always @(*) begin
        case (pc)
            3'h0: tasks = REPEAT_7                    | // init stack
                          PUSH_X                      ;
            3'h1: tasks = WAIT_IN                     ;
            3'h2: tasks = PUSH_X                      |
                          MOV_I_0                     |
                          MOV_J_0                     |
                          MOV_IX_XHEAD                ;
            3'h3: tasks = REPEAT_7                    |
                          MAC_CIJ_X                   |
                          INC_I                       |
                          INC_IX_CIRC                 ;
            3'h4: tasks = MOV_I_0                     |
                          INC_J                       ;
            3'h5: tasks = NOP                         ;
            3'h6: tasks = MOV_RES_AC                  |
                          (j_reg == 0 ? DONE : NOP )  |
                          (j_reg == 0 ? JP_1 : JP_3)  ;
            default: tasks = JP_1                     ;
        endcase
    end


    // PC
    reg [2:0] pc;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            pc <= 3'h0;
        end
        else if (tasks & JP_1) begin
            pc <= 3'h1;
        end
        else if (tasks & JP_3) begin
            pc <= 3'h3;
        end
        else if ((tasks & WAIT_IN  && !sample_in_rdy) ||
                 (tasks & REPEAT_7 && repeat_st     ))
        begin
            pc <= pc;
        end
        else begin
            pc <= pc + 3'h1;
        end
    end


    // REPEAT
    reg  [2:0] repeat_cnt;
    wire [2:0] repeat_cnt_max = (tasks & REPEAT_7) ? 'h6 : 'h0;
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


    // INDEX REGISTER I (0-6)
    reg  [2:0] i_reg;
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
    end

    // INDEX REGISTER J (0-7)
    reg  [2:0] j_reg;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            j_reg <= 'h0;
        end
        else if (tasks & MOV_J_0) begin
            j_reg <= 'h0;
        end
        else if (tasks & INC_J) begin
            j_reg <= j_reg + 'h1;
        end
    end


    // CRICULAR X INDEX REGISTER (0-7)
    reg  [2:0] ix_reg;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            ix_reg <= 'h0;
        end
        else if (tasks & MOV_IX_XHEAD) begin
            ix_reg <= x_buf_head_cnt;
        end
        else if (tasks & INC_IX_CIRC) begin
            ix_reg <= (ix_reg == 'h6) ? 'h0 : (ix_reg + 'h1);
        end
    end


    // Delay Line
    wire push_x = (tasks & PUSH_X   ) ? 1'b1 : 1'b0;
    wire read_x = (tasks & MAC_CIJ_X) ? 1'b1 : 1'b0;

    reg [2:0] x_buf_head_cnt;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            x_buf_head_cnt <= 'h0;
        end
        else if (push_x) begin
            x_buf_head_cnt <= (x_buf_head_cnt == 0) ? 'h6 : (x_buf_head_cnt-'h1);
        end
    end

    wire               xbuf_wr      = push_x;
    wire        [2:0]  xbuf_wr_addr = x_buf_head_cnt;
    wire        [35:0] xbuf_wr_data = {sample_in_reg_l, sample_in_reg_r};
    wire               xbuf_rd      = read_x;
    wire        [2:0]  xbuf_rd_addr = ix_reg;
    wire        [35:0] xbuf_rd_data;
    wire signed [17:0] xjl          = xbuf_rd_data[35:18];
    wire signed [17:0] xjr          = xbuf_rd_data[17:0];

    // TODO: Change to the B_RAM
    dp_ram #(.DATA_W(36), .ADDR_W(3), .RAM_DEPTH(7)) x_buf_ram
    (
        .clk       (clk          ),
        .wr_addr   (xbuf_wr_addr ),
        .wr_data   (xbuf_wr_data ),
        .wr        (xbuf_wr      ),
        .rd_addr   (xbuf_rd_addr ),
        .rd_data   (xbuf_rd_data ),
        .rd        (xbuf_rd      )
    );     


    // Coefficients
    wire       [5:0]  cij_idx = {i_reg, j_reg};
    reg signed [17:0] cij;

    always @(cij_idx) begin
        case (cij_idx)
            'h0    : begin cij <= 18'h3FFFA; end
            'h1    : begin cij <= 18'h3FFF8; end
            'h2    : begin cij <= 18'h3FFFF; end
            'h3    : begin cij <= 18'h018B9; end
            'h4    : begin cij <= 18'h04C48; end
            'h5    : begin cij <= 18'h09C73; end
            'h6    : begin cij <= 18'h0100C; end
            'h7    : begin cij <= 18'h0161C; end
            'h8    : begin cij <= 18'h0197A; end
            'h9    : begin cij <= 18'h016E7; end
            'ha    : begin cij <= 18'h0AFD1; end
            'hb    : begin cij <= 18'h3FF32; end
            'hc    : begin cij <= 18'h3FCEE; end
            'hd    : begin cij <= 18'h3FA0B; end
            'he    : begin cij <= 18'h3F6F3; end
            'hf    : begin cij <= 18'h3F44E; end
            'h10   : begin cij <= 18'h3F2F9; end
            'h11   : begin cij <= 18'h3F3E7; end
            'h12   : begin cij <= 18'h3F7FC; end
            'h13   : begin cij <= 18'h3FFDC; end
            'h14   : begin cij <= 18'h0BC0C; end
            'h15   : begin cij <= 18'h01B54; end
            'h16   : begin cij <= 18'h02DAB; end
            'h17   : begin cij <= 18'h04151; end
            'h18   : begin cij <= 18'h0546F; end
            'h19   : begin cij <= 18'h0650B; end
            'h1a   : begin cij <= 18'h07150; end
            'h1b   : begin cij <= 18'h077D5; end

            'h1c   : begin cij <= 18'h077D5; end
            'h1d   : begin cij <= 18'h07150; end
            'h1e   : begin cij <= 18'h0650B; end
            'h1f   : begin cij <= 18'h0546F; end
            'h20   : begin cij <= 18'h04151; end
            'h21   : begin cij <= 18'h02DAB; end
            'h22   : begin cij <= 18'h01B54; end
            'h23   : begin cij <= 18'h0BC0C; end
            'h24   : begin cij <= 18'h3FFDC; end
            'h25   : begin cij <= 18'h3F7FC; end
            'h26   : begin cij <= 18'h3F3E7; end
            'h27   : begin cij <= 18'h3F2F9; end
            'h28   : begin cij <= 18'h3F44E; end
            'h29   : begin cij <= 18'h3F6F3; end
            'h2a   : begin cij <= 18'h3FA0B; end
            'h2b   : begin cij <= 18'h3FF32; end
            'h2c   : begin cij <= 18'h3FCEE; end
            'h2d   : begin cij <= 18'h0AFD1; end
            'h2e   : begin cij <= 18'h016E7; end
            'h2f   : begin cij <= 18'h0197A; end
            'h30   : begin cij <= 18'h0161C; end
            'h31   : begin cij <= 18'h0100C; end
            'h32   : begin cij <= 18'h09C73; end
            'h33   : begin cij <= 18'h04C48; end
            'h34   : begin cij <= 18'h018B9; end
            'h35   : begin cij <= 18'h3FFFF; end
            'h36   : begin cij <= 18'h3FFF8; end
            'h37   : begin cij <= 18'h3FFFA; end
            default: begin cij <= 18'h00000; end
        endcase
    end


    // MUL TASKS
    always @(*) begin
        opmode = `DSP_NOP;
        al     = 18'h00000;
        ar     = 18'h00000;
        bl     = 18'h00000;
        br     = 18'h00000;

        if (tasks & MAC_CIJ_X) begin
            opmode = `DSP_XIN_MULT | `DSP_ZIN_POUT;
            al     = cij;
            ar     = cij;
            bl     = xjl;
            br     = xjr;
        end
    end


    // MOVE AC VALUE TO RESULTS
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            sample_out_rdy <= 1'b0;
            sample_out_l   <= 18'h00000;
            sample_out_r   <= 18'h00000;
        end
        else if (tasks & MOV_RES_AC) begin
            sample_out_rdy <= 1'b1;
            sample_out_l   <= pl[33:16];
            sample_out_r   <= pr[33:16];
        end
        else begin
            sample_out_rdy <= 1'b0;
            sample_out_l   <= 18'h00000;
            sample_out_r   <= 18'h00000;
        end
    end


    // SET DONE
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            done <= 1'b0;
        end
        else if (tasks & DONE) begin
            done <= 1'b1;
        end
        else begin
            done <= 1'b0;
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
