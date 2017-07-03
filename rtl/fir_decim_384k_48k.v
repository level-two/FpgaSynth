// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: fir_decim_384k_48k.v
// Description: Decimating FIR 384k->48k implementation
// -----------------------------------------------------------------------------

`include "globals.vh"

module fir_decim_384k_48k (
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

    localparam CCNT         = 'hba;
    localparam CCNT_W       = 8;
    localparam RCNT_W       = CCNT_W;
    localparam DECIM_FACTOR = 8;

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
    localparam [15:0] REPEAT_COEFS_NUM = 16'h0100;
    localparam [15:0] JP_1             = 16'h0200;

    reg [15:0] tasks;
    always @(pc) begin
        case (pc)
            5'h0   : tasks = REPEAT_COEFS_NUM       | // init stack
                             PUSH_X                 ;
            5'h1   : tasks = WAIT_IN                ;
            5'h2   : tasks = PUSH_X                 ;
            5'h3   : tasks = WAIT_IN                ;
            5'h4   : tasks = PUSH_X                 ;
            5'h5   : tasks = WAIT_IN                ;
            5'h6   : tasks = PUSH_X                 ;
            5'h7   : tasks = WAIT_IN                ;
            5'h8   : tasks = PUSH_X                 ;
            5'h9   : tasks = WAIT_IN                ;
            5'ha   : tasks = PUSH_X                 ;
            5'hb   : tasks = WAIT_IN                ;
            5'hc   : tasks = PUSH_X                 ;
            5'hd   : tasks = WAIT_IN                ;
            5'he   : tasks = PUSH_X                 ;
            5'hf   : tasks = WAIT_IN                ;
            5'h10  : tasks = PUSH_X                 |
                             MOV_I_0                |
                             MOV_J_XHEAD            ;
            5'h11  : tasks = REPEAT_COEFS_NUM       |
                             MAC_CI_XJ              |
                             INC_I                  |
                             INC_J_CIRC             ;
            5'h12  : tasks = NOP                    ;
            5'h13  : tasks = NOP                    ;
            5'h14  : tasks = MOV_RES_AC             |
                             JP_1                   ;
            default: tasks = JP_1                   ;
        endcase
    end


    // PC
    reg [4:0] pc;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            pc <= 5'h0;
        end
        else if (tasks & JP_1) begin
            pc <= 5'h1;
        end
        else if ((tasks & WAIT_IN          && !sample_in_rdy) ||
                 (tasks & REPEAT_COEFS_NUM && repeat_st     ))
        begin
            pc <= pc;
        end
        else begin
            pc <= pc + 5'h1;
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
    wire read_xj   = (tasks & MAC_CI_XJ) ? 1'b1 : 1'b0;

    reg [CCNT_W-1:0] x_buf_head_cnt;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            x_buf_head_cnt <= 'h0;
        end
        else if (push_x) begin
            x_buf_head_cnt <= (x_buf_head_cnt == 0) ? (CCNT-1) : (x_buf_head_cnt-1);
        end
    end

    wire               xbuf_wr      = push_x;
    wire [CCNT_W-1:0]  xbuf_wr_addr = x_buf_head_cnt;
    wire [35:0]        xbuf_wr_data = {sample_in_reg_l, sample_in_reg_r};
    wire               xbuf_rd      = read_xj;
    wire [CCNT_W-1:0]  xbuf_rd_addr = j_reg;
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
            'h0    : begin ci <= 18'h3FFFF; end
            'h1    : begin ci <= 18'h3FFFF; end
            'h2    : begin ci <= 18'h3FFFF; end
            'h3    : begin ci <= 18'h00000; end
            'h4    : begin ci <= 18'h00000; end
            'h5    : begin ci <= 18'h00001; end
            'h6    : begin ci <= 18'h00003; end
            'h7    : begin ci <= 18'h00005; end
            'h8    : begin ci <= 18'h00007; end
            'h9    : begin ci <= 18'h00008; end
            'ha    : begin ci <= 18'h00008; end
            'hb    : begin ci <= 18'h00008; end
            'hc    : begin ci <= 18'h00006; end
            'hd    : begin ci <= 18'h00003; end
            'he    : begin ci <= 18'h3FFFF; end
            'hf    : begin ci <= 18'h3FFFA; end
            'h10   : begin ci <= 18'h3FFF4; end
            'h11   : begin ci <= 18'h3FFEE; end
            'h12   : begin ci <= 18'h3FFE9; end
            'h13   : begin ci <= 18'h3FFE7; end
            'h14   : begin ci <= 18'h3FFE6; end
            'h15   : begin ci <= 18'h3FFE9; end
            'h16   : begin ci <= 18'h3FFF0; end
            'h17   : begin ci <= 18'h3FFFA; end
            'h18   : begin ci <= 18'h00005; end
            'h19   : begin ci <= 18'h00013; end
            'h1a   : begin ci <= 18'h00021; end
            'h1b   : begin ci <= 18'h0002E; end
            'h1c   : begin ci <= 18'h00038; end
            'h1d   : begin ci <= 18'h0003C; end
            'h1e   : begin ci <= 18'h0003A; end
            'h1f   : begin ci <= 18'h00031; end
            'h20   : begin ci <= 18'h00021; end
            'h21   : begin ci <= 18'h0000B; end
            'h22   : begin ci <= 18'h3FFF0; end
            'h23   : begin ci <= 18'h3FFD2; end
            'h24   : begin ci <= 18'h3FFB6; end
            'h25   : begin ci <= 18'h3FF9D; end
            'h26   : begin ci <= 18'h3FF8C; end
            'h27   : begin ci <= 18'h3FF86; end
            'h28   : begin ci <= 18'h3FF8D; end
            'h29   : begin ci <= 18'h3FFA2; end
            'h2a   : begin ci <= 18'h3FFC5; end
            'h2b   : begin ci <= 18'h3FFF3; end
            'h2c   : begin ci <= 18'h00027; end
            'h2d   : begin ci <= 18'h0005F; end
            'h2e   : begin ci <= 18'h00094; end
            'h2f   : begin ci <= 18'h000BF; end
            'h30   : begin ci <= 18'h000D9; end
            'h31   : begin ci <= 18'h000DF; end
            'h32   : begin ci <= 18'h000CD; end
            'h33   : begin ci <= 18'h000A2; end
            'h34   : begin ci <= 18'h0005F; end
            'h35   : begin ci <= 18'h0000A; end
            'h36   : begin ci <= 18'h3FFAB; end
            'h37   : begin ci <= 18'h3FF48; end
            'h38   : begin ci <= 18'h3FEEE; end
            'h39   : begin ci <= 18'h3FEA7; end
            'h3a   : begin ci <= 18'h3FE7E; end
            'h3b   : begin ci <= 18'h3FE7B; end
            'h3c   : begin ci <= 18'h3FEA2; end
            'h3d   : begin ci <= 18'h3FEF5; end
            'h3e   : begin ci <= 18'h3FF6F; end
            'h3f   : begin ci <= 18'h00006; end
            'h40   : begin ci <= 18'h000AF; end
            'h41   : begin ci <= 18'h0015A; end
            'h42   : begin ci <= 18'h001F4; end
            'h43   : begin ci <= 18'h00269; end
            'h44   : begin ci <= 18'h002A9; end
            'h45   : begin ci <= 18'h002A6; end
            'h46   : begin ci <= 18'h00258; end
            'h47   : begin ci <= 18'h001BE; end
            'h48   : begin ci <= 18'h000DE; end
            'h49   : begin ci <= 18'h3FFC7; end
            'h4a   : begin ci <= 18'h3FE8F; end
            'h4b   : begin ci <= 18'h3FD53; end
            'h4c   : begin ci <= 18'h3FC32; end
            'h4d   : begin ci <= 18'h3FB51; end
            'h4e   : begin ci <= 18'h3FAD1; end
            'h4f   : begin ci <= 18'h3FAD0; end
            'h50   : begin ci <= 18'h3FB64; end
            'h51   : begin ci <= 18'h3FC9A; end
            'h52   : begin ci <= 18'h3FE75; end
            'h53   : begin ci <= 18'h000EA; end
            'h54   : begin ci <= 18'h003E3; end
            'h55   : begin ci <= 18'h0073E; end
            'h56   : begin ci <= 18'h00AD0; end
            'h57   : begin ci <= 18'h00E67; end
            'h58   : begin ci <= 18'h011CF; end
            'h59   : begin ci <= 18'h014D4; end
            'h5a   : begin ci <= 18'h01746; end
            'h5b   : begin ci <= 18'h018FF; end
            'h5c   : begin ci <= 18'h019E3; end
            'h5d   : begin ci <= 18'h019E3; end
            'h5e   : begin ci <= 18'h018FF; end
            'h5f   : begin ci <= 18'h01746; end
            'h60   : begin ci <= 18'h014D4; end
            'h61   : begin ci <= 18'h011CF; end
            'h62   : begin ci <= 18'h00E67; end
            'h63   : begin ci <= 18'h00AD0; end
            'h64   : begin ci <= 18'h0073E; end
            'h65   : begin ci <= 18'h003E3; end
            'h66   : begin ci <= 18'h000EA; end
            'h67   : begin ci <= 18'h3FE75; end
            'h68   : begin ci <= 18'h3FC9A; end
            'h69   : begin ci <= 18'h3FB64; end
            'h6a   : begin ci <= 18'h3FAD0; end
            'h6b   : begin ci <= 18'h3FAD1; end
            'h6c   : begin ci <= 18'h3FB51; end
            'h6d   : begin ci <= 18'h3FC32; end
            'h6e   : begin ci <= 18'h3FD53; end
            'h6f   : begin ci <= 18'h3FE8F; end
            'h70   : begin ci <= 18'h3FFC7; end
            'h71   : begin ci <= 18'h000DE; end
            'h72   : begin ci <= 18'h001BE; end
            'h73   : begin ci <= 18'h00258; end
            'h74   : begin ci <= 18'h002A6; end
            'h75   : begin ci <= 18'h002A9; end
            'h76   : begin ci <= 18'h00269; end
            'h77   : begin ci <= 18'h001F4; end
            'h78   : begin ci <= 18'h0015A; end
            'h79   : begin ci <= 18'h000AF; end
            'h7a   : begin ci <= 18'h00006; end
            'h7b   : begin ci <= 18'h3FF6F; end
            'h7c   : begin ci <= 18'h3FEF5; end
            'h7d   : begin ci <= 18'h3FEA2; end
            'h7e   : begin ci <= 18'h3FE7B; end
            'h7f   : begin ci <= 18'h3FE7E; end
            'h80   : begin ci <= 18'h3FEA7; end
            'h81   : begin ci <= 18'h3FEEE; end
            'h82   : begin ci <= 18'h3FF48; end
            'h83   : begin ci <= 18'h3FFAB; end
            'h84   : begin ci <= 18'h0000A; end
            'h85   : begin ci <= 18'h0005F; end
            'h86   : begin ci <= 18'h000A2; end
            'h87   : begin ci <= 18'h000CD; end
            'h88   : begin ci <= 18'h000DF; end
            'h89   : begin ci <= 18'h000D9; end
            'h8a   : begin ci <= 18'h000BF; end
            'h8b   : begin ci <= 18'h00094; end
            'h8c   : begin ci <= 18'h0005F; end
            'h8d   : begin ci <= 18'h00027; end
            'h8e   : begin ci <= 18'h3FFF3; end
            'h8f   : begin ci <= 18'h3FFC5; end
            'h90   : begin ci <= 18'h3FFA2; end
            'h91   : begin ci <= 18'h3FF8D; end
            'h92   : begin ci <= 18'h3FF86; end
            'h93   : begin ci <= 18'h3FF8C; end
            'h94   : begin ci <= 18'h3FF9D; end
            'h95   : begin ci <= 18'h3FFB6; end
            'h96   : begin ci <= 18'h3FFD2; end
            'h97   : begin ci <= 18'h3FFF0; end
            'h98   : begin ci <= 18'h0000B; end
            'h99   : begin ci <= 18'h00021; end
            'h9a   : begin ci <= 18'h00031; end
            'h9b   : begin ci <= 18'h0003A; end
            'h9c   : begin ci <= 18'h0003C; end
            'h9d   : begin ci <= 18'h00038; end
            'h9e   : begin ci <= 18'h0002E; end
            'h9f   : begin ci <= 18'h00021; end
            'ha0   : begin ci <= 18'h00013; end
            'ha1   : begin ci <= 18'h00005; end
            'ha2   : begin ci <= 18'h3FFFA; end
            'ha3   : begin ci <= 18'h3FFF0; end
            'ha4   : begin ci <= 18'h3FFE9; end
            'ha5   : begin ci <= 18'h3FFE6; end
            'ha6   : begin ci <= 18'h3FFE7; end
            'ha7   : begin ci <= 18'h3FFE9; end
            'ha8   : begin ci <= 18'h3FFEE; end
            'ha9   : begin ci <= 18'h3FFF4; end
            'haa   : begin ci <= 18'h3FFFA; end
            'hab   : begin ci <= 18'h3FFFF; end
            'hac   : begin ci <= 18'h00003; end
            'had   : begin ci <= 18'h00006; end
            'hae   : begin ci <= 18'h00008; end
            'haf   : begin ci <= 18'h00008; end
            'hb0   : begin ci <= 18'h00008; end
            'hb1   : begin ci <= 18'h00007; end
            'hb2   : begin ci <= 18'h00005; end
            'hb3   : begin ci <= 18'h00003; end
            'hb4   : begin ci <= 18'h00001; end
            'hb5   : begin ci <= 18'h00000; end
            'hb6   : begin ci <= 18'h00000; end
            'hb7   : begin ci <= 18'h3FFFF; end
            'hb8   : begin ci <= 18'h3FFFF; end
            'hb9   : begin ci <= 18'h3FFFF; end
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
