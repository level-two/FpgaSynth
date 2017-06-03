// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: fir_interpolator_2x.v
// Description: IIR implementation based on Xilinx DSP48A1
// -----------------------------------------------------------------------------

`include "globals.vh"

module fir_interpolator_2x (
    input                    clk,
    input                    reset,

    input                    sample_in_rdy,
    input  signed [17:0]     sample_in_l,
    input  signed [17:0]     sample_in_r,

    output reg               sample_out_rdy,
    output reg signed [17:0] sample_out_l,
    output reg signed [17:0] sample_out_r,

    input  [47:0]            dsp_outs_flat_l,
    input  [47:0]            dsp_outs_flat_r,
    output [91:0]            dsp_ins_flat_l,
    output [91:0]            dsp_ins_flat_r
);

    localparam CCNT_W = 6;
    localparam RCNT_W = CCNT_W;
    localparam [CCNT_W-1:0] CCNT = 34;


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
    localparam [15:0] PUSH_X           = 16'h0002;
    localparam [15:0] MOV_I_0          = 16'h0004;
    localparam [15:0] INC_I            = 16'h0008;
    localparam [15:0] MOV_J_XHEAD      = 16'h0010;
    localparam [15:0] INC_J_CIRC       = 16'h0020;
    localparam [15:0] MAC_CI_XJ        = 16'h0040;
    localparam [15:0] MOV_RES_AC       = 16'h0080;
    localparam [15:0] MOV_RES_05_XMID  = 16'h0100;
    localparam [15:0] REPEAT_3         = 16'h0200;
    localparam [15:0] REPEAT_COEFS_NUM = 16'h0400;
    localparam [15:0] JP_2             = 16'h0800;

    reg [15:0] tasks;
    always @(pc) begin
        case (pc)
            4'h0   : tasks = MOV_I_0                ;
            4'h1   : tasks = REPEAT_COEFS_NUM       | // init stack
                             PUSH_X                 ;
            4'h2   : tasks = WAIT_IN                ;
            4'h3   : tasks = PUSH_X                 |
                             MOV_I_0                |
                             MOV_J_XHEAD            ;
            4'h4   : tasks = REPEAT_COEFS_NUM       |
                             MAC_CI_XJ              |
                             INC_I                  |
                             INC_J_CIRC             ;
            4'h5   : tasks = REPEAT_3               |
                             NOP                    ;
            4'h6   : tasks = MOV_RES_AC             ;
            4'h7   : tasks = MOV_RES_05_XMID        ;
            4'h8   : tasks = JP_2                   ;
            default: tasks = JP_2                   ;
        endcase
    end


    // PC
    reg [3:0] pc;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            pc <= 4'h0;
        end
        else if (tasks & JP_2) begin
            pc <= 4'h2;
        end
        else if ((tasks & WAIT_IN          && !sample_in_rdy) ||
                 (tasks & REPEAT_3         && repeat_st     ) ||
                 (tasks & REPEAT_COEFS_NUM && repeat_st     ))
        begin
            pc <= pc;
        end
        else begin
            pc <= pc + 4'h1;
        end
    end


    // REPEAT
    reg  [RCNT_W-1:0] repeat_cnt;
    wire [RCNT_W-1:0] repeat_cnt_max = (tasks & REPEAT_3        ) ? 'h2    :
                                       (tasks & REPEAT_COEFS_NUM) ? CCNT-1 :
                                       'h0;
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
    reg  [CCNT_W-1:0] i_reg;
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

    reg  [CCNT_W-1:0] j_reg;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            j_reg <= 'h0;
        end
        else if (tasks & MOV_J_XHEAD) begin
            j_reg <= x_buf_head_cnt;
        end
        else if (tasks & INC_I) begin
            j_reg <= j_reg + 'h1;
        end
    end


    // Delay Line
    wire push_x    = (tasks & PUSH_X) ? 1'b1 : 1'b0;
    wire read_xj   = ((tasks & MAC_CI_XJ) || (tasks & MOV_RES_05_XMID));

    reg [CCNT_W-1:0] x_buf_head_cnt;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            x_buf_head_cnt <= 'h0;
        end
        else if (push_x) begin
            x_buf_head_cnt <= (x_buf_head_cnt == 0) ?
                (CCNT-1) : (x_buf_head_cnt - 'h1);
        end
    end

    wire               xbuf_wr      = push_x;
    wire [CCNT_W-1:0]  xbuf_wr_addr = x_buf_head_cnt;
    wire [35:0]        xbuf_wr_data = {sample_in_reg_l, sample_in_reg_r};
    wire               xbuf_rd      = read_xj;
    wire [CCNT_W-1:0]  xbuf_rd_addr = (tasks & MOV_RES_05_XMID) ? (CCNT>>1-1) : j_reg;
    wire [35:0]        xbuf_rd_data;
    wire signed [17:0] xjl          = xbuf_rd_data[35:18];
    wire signed [17:0] xjr          = xbuf_rd_data[17:0];

    // TODO: Change to the B_RAM
    dp_ram #(.DATA_W(36), .ADDR_W(CCNT_W), .RAM_DEPTH(CCNT)) x_buf_ram
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
    reg signed [17:0] ci;
    always @(i_reg) begin
        case (i_reg)
            'h0    : begin ci <= 18'h00001; end
            'h1    : begin ci <= 18'h3FFFB; end
            'h2    : begin ci <= 18'h0000D; end
            'h3    : begin ci <= 18'h3FFE2; end
            'h4    : begin ci <= 18'h00038; end
            'h5    : begin ci <= 18'h3FF9B; end
            'h6    : begin ci <= 18'h000A7; end
            'h7    : begin ci <= 18'h3FEF7; end
            'h8    : begin ci <= 18'h00191; end
            'h9    : begin ci <= 18'h3FDB1; end
            'ha    : begin ci <= 18'h00352; end
            'hb    : begin ci <= 18'h3FB45; end
            'hc    : begin ci <= 18'h006B8; end
            'hd    : begin ci <= 18'h3F644; end
            'he    : begin ci <= 18'h00EE1; end
            'hf    : begin ci <= 18'h3E5B5; end
            'h10   : begin ci <= 18'h05131; end

            'h11   : begin ci <= 18'h05131; end
            'h12   : begin ci <= 18'h3E5B5; end
            'h13   : begin ci <= 18'h00EE1; end
            'h14   : begin ci <= 18'h3F644; end
            'h15   : begin ci <= 18'h006B8; end
            'h16   : begin ci <= 18'h3FB45; end
            'h17   : begin ci <= 18'h00352; end
            'h18   : begin ci <= 18'h3FDB1; end
            'h19   : begin ci <= 18'h00191; end
            'h1a   : begin ci <= 18'h3FEF7; end
            'h1b   : begin ci <= 18'h000A7; end
            'h1c   : begin ci <= 18'h3FF9B; end
            'h1d   : begin ci <= 18'h00038; end
            'h1e   : begin ci <= 18'h3FFE2; end
            'h1f   : begin ci <= 18'h0000D; end
            'h20   : begin ci <= 18'h3FFFB; end
            'h21   : begin ci <= 18'h00001; end

            default: begin ci <= 18'h00000; end
        endcase
    end


    // MUL TASKS
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            opmode <= `DSP_NOP;
            al     <= 18'h00000;
            ar     <= 18'h00000;
            bl     <= 18'h00000;
            br     <= 18'h00000;
        end
        else if (tasks & MAC_CI_XJ) begin
            opmode <= `DSP_XIN_MULT | `DSP_ZIN_POUT;
            al     <= ci;
            ar     <= ci;
            bl     <= xjl;
            br     <= xjr;
        end
        else begin
            opmode <= `DSP_NOP;
            al     <= 18'h00000;
            ar     <= 18'h00000;
            bl     <= 18'h00000;
            br     <= 18'h00000;
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
        else if (tasks & MOV_RES_05_XMID) begin
            sample_out_rdy <= 1'b1;
            sample_out_l   <= xbuf_rd_data[35:18] >>> 1;
            sample_out_r   <= xbuf_rd_data[17:0] >>> 1;
        end
        else begin
            sample_out_rdy <= 1'b0;
            sample_out_l   <= 18'h00000;
            sample_out_r   <= 18'h00000;
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
