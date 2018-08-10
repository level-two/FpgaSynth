// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: fir_interp_halfband_2x.v
// Description: Halfband 2x-interpolating FIR implementation
// -----------------------------------------------------------------------------

`include "../globals.vh"

module fir_interp_halfband_2x (
    input                    clk,
    input                    reset,

    input                    sample_in_rdy,
    input  signed [17:0]     sample_in_l,
    input  signed [17:0]     sample_in_r,

    output reg               sample_out_rdy,
    output reg signed [17:0] sample_out_l,
    output reg signed [17:0] sample_out_r,
    output reg               done,

    output reg        [ 7:0] opl   ,
    output reg signed [17:0] al    ,
    output reg signed [17:0] bl    ,
    output     signed [47:0] cl    ,
    input      signed [47:0] pl    ,
    output reg        [ 7:0] opr   ,
    output reg signed [17:0] ar    ,
    output reg signed [17:0] br    ,
    output     signed [47:0] cr    ,
    input      signed [47:0] pr    
);

    localparam CCNT_W = 6;
    localparam RCNT_W = CCNT_W;
    localparam [CCNT_W-1:0] CCNT = 34;
    localparam XMID_ADR = 17;


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
    localparam [15:0] MOV_RES_XMID     = 16'h0100;
    localparam [15:0] REPEAT_COEFS_NUM = 16'h0200;
    localparam [15:0] JP_1             = 16'h0400;
    localparam [15:0] DONE             = 16'h0800;

    reg [15:0] tasks;
    always @(*) begin
        case (pc)
            4'h0   : tasks = REPEAT_COEFS_NUM       | // init stack
                             PUSH_X                 ;
            4'h1   : tasks = WAIT_IN                ;
            4'h2   : tasks = PUSH_X                 |
                             MOV_I_0                |
                             MOV_J_XHEAD            ;
            4'h3   : tasks = REPEAT_COEFS_NUM       |
                             MAC_CI_XJ              |
                             INC_I                  |
                             INC_J_CIRC             ;
            4'h4   : tasks = NOP                    ;
            4'h5   : tasks = NOP                    ;
            4'h6   : tasks = MOV_RES_AC             ;
            4'h7   : tasks = MOV_RES_XMID           |
                             DONE                   ;
            4'h8   : tasks = JP_1                   ;
            default: tasks = JP_1                   ;
        endcase
    end


    // PC
    reg [3:0] pc;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            pc <= 4'h0;
        end
        else if (tasks & JP_1) begin
            pc <= 4'h1;
        end
        else if ((tasks & WAIT_IN          && !sample_in_rdy) ||
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
    wire [RCNT_W-1:0] repeat_cnt_max = (tasks & REPEAT_COEFS_NUM) ? CCNT-1 :
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
        else if (tasks & INC_J_CIRC) begin
            j_reg <= (j_reg == CCNT-1) ? 'h0 : j_reg + 'h1;
        end
    end


    // Delay Line
    wire push_x    = (tasks & PUSH_X) ? 1'b1 : 1'b0;
    wire read_xj   = (tasks & (MAC_CI_XJ | MOV_RES_XMID)) ? 1'b1 : 1'b0;

    reg [CCNT_W-1:0] x_buf_head_cnt;
    reg [CCNT_W-1:0] x_buf_mid_cnt;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            x_buf_head_cnt <= 'h0;
            x_buf_mid_cnt  <= XMID_ADR;
        end
        else if (push_x) begin
            x_buf_head_cnt <= (x_buf_head_cnt == 0) ?
                (CCNT-1) : (x_buf_head_cnt - 'h1);

            x_buf_mid_cnt  <= (x_buf_mid_cnt == 0) ?
                (CCNT-1) : (x_buf_mid_cnt - 'h1);
        end
    end

    wire               xbuf_wr      = push_x;
    wire [CCNT_W-1:0]  xbuf_wr_addr = x_buf_head_cnt;
    wire [35:0]        xbuf_wr_data = {sample_in_reg_l, sample_in_reg_r};
    wire               xbuf_rd      = read_xj;
    wire [CCNT_W-1:0]  xbuf_rd_addr = (tasks & MOV_RES_XMID) ? x_buf_mid_cnt : j_reg;
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
            'h0    : begin ci <= 18'h00002; end
            'h1    : begin ci <= 18'h3FFF6; end
            'h2    : begin ci <= 18'h0001A; end
            'h3    : begin ci <= 18'h3FFC5; end
            'h4    : begin ci <= 18'h00071; end
            'h5    : begin ci <= 18'h3FF36; end
            'h6    : begin ci <= 18'h0014E; end
            'h7    : begin ci <= 18'h3FDEF; end
            'h8    : begin ci <= 18'h00322; end
            'h9    : begin ci <= 18'h3FB62; end
            'ha    : begin ci <= 18'h006A5; end
            'hb    : begin ci <= 18'h3F68B; end
            'hc    : begin ci <= 18'h00D71; end
            'hd    : begin ci <= 18'h3EC88; end
            'he    : begin ci <= 18'h01DC3; end
            'hf    : begin ci <= 18'h3CB6A; end
            'h10   : begin ci <= 18'h0A263; end
            'h11   : begin ci <= 18'h0A263; end
            'h12   : begin ci <= 18'h3CB6A; end
            'h13   : begin ci <= 18'h01DC3; end
            'h14   : begin ci <= 18'h3EC88; end
            'h15   : begin ci <= 18'h00D71; end
            'h16   : begin ci <= 18'h3F68B; end
            'h17   : begin ci <= 18'h006A5; end
            'h18   : begin ci <= 18'h3FB62; end
            'h19   : begin ci <= 18'h00322; end
            'h1a   : begin ci <= 18'h3FDEF; end
            'h1b   : begin ci <= 18'h0014E; end
            'h1c   : begin ci <= 18'h3FF36; end
            'h1d   : begin ci <= 18'h00071; end
            'h1e   : begin ci <= 18'h3FFC5; end
            'h1f   : begin ci <= 18'h0001A; end
            'h20   : begin ci <= 18'h3FFF6; end
            'h21   : begin ci <= 18'h00002; end
            default: begin ci <= 18'h00000; end
        endcase
    end


    // MUL TASKS
    always @(*) begin
        opl = `DSP_NOP;
        opr = `DSP_NOP;
        al  = 18'h00000;
        ar  = 18'h00000;
        bl  = 18'h00000;
        br  = 18'h00000;

        if (tasks & MAC_CI_XJ) begin
            opl = `DSP_XIN_MULT | `DSP_ZIN_POUT;
            opr = `DSP_XIN_MULT | `DSP_ZIN_POUT;
            al  = ci;
            ar  = ci;
            bl  = xjl;
            br  = xjr;
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
        else if (tasks & MOV_RES_XMID) begin
            sample_out_rdy <= 1'b1;
            sample_out_l   <= xbuf_rd_data[35:18];
            sample_out_r   <= xbuf_rd_data[17:0];
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
    assign cl = 48'b0;
    assign cr = 48'b0;
endmodule
