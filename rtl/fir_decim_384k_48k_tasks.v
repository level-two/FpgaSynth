// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: fir_decim_384k_48k_tasks.v
// Description: Decimating FIR 384k->48k implementation
// -----------------------------------------------------------------------------

`include "globals.vh"

module fir_decim_384k_48k_tasks (
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

    localparam PC_W = 5;

    localparam CCNT         = 34;
    localparam CCNT_W       = 6;
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
            'h0    : tasks = REPEAT_COEFS_NUM       | // init stack
                             PUSH_X                 ;
            'h1    : tasks = WAIT_IN                ;
            'h2    : tasks = PUSH_X                 ;
            'h3    : tasks = WAIT_IN                ;
            'h4    : tasks = PUSH_X                 ;
            'h5    : tasks = WAIT_IN                ;
            'h6    : tasks = PUSH_X                 ;
            'h7    : tasks = WAIT_IN                ;
            'h8    : tasks = PUSH_X                 ;
            'h9    : tasks = WAIT_IN                ;
            'ha    : tasks = PUSH_X                 ;
            'hb    : tasks = WAIT_IN                ;
            'hc    : tasks = PUSH_X                 ;
            'hd    : tasks = WAIT_IN                ;
            'he    : tasks = PUSH_X                 ;
            'hf    : tasks = WAIT_IN                ;
            'h10   : tasks = PUSH_X                 |
                             MOV_I_0                |
                             MOV_J_XHEAD            ;
            'h11   : tasks = REPEAT_COEFS_NUM       |
                             MAC_CI_XJ              |
                             INC_I                  |
                             INC_J_CIRC             ;
            'h12   : tasks = NOP                    ;
            'h13   : tasks = NOP                    ;
            'h14   : tasks = MOV_RES_AC             |
                             JP_1                   ;
            default: tasks = JP_1                   ;
        endcase
    end


    wire task_wait_in     = (tasks & WAIT_IN         ) ? 1'b1 : 1'b0;
    wire task_jp1         = (tasks & JP_1            ) ? 1'b1 : 1'b0;
    wire task_repeat      = (tasks & REPEAT_COEFS_NUM) ? 1'b1 : 1'b0;
    wire task_push_x      = (tasks & PUSH_X          ) ? 1'b1 : 1'b0;
    wire task_mov_i_0     = (tasks & MOV_I_0         ) ? 1'b1 : 1'b0;
    wire task_inc_i       = (tasks & INC_I           ) ? 1'b1 : 1'b0;
    wire task_mov_j_xhead = (tasks & MOV_J_XHEAD     ) ? 1'b1 : 1'b0;
    wire task_inc_j_circ  = (tasks & INC_J_CIRC      ) ? 1'b1 : 1'b0;
    wire task_mac_ci_xj   = (tasks & MAC_CI_XJ       ) ? 1'b1 : 1'b0;
    wire task_mov_res_ac  = (tasks & MOV_RES_AC      ) ? 1'b1 : 1'b0;




    wire is_waiting_in = task_wait_in & !sample_in_rdy;

    // PC
    wire [PC_W-1:0] jp_addr  = task_jp1 ? 1    : 0;
    wire            jp_stb   = task_jp1 ? 1'b1 : 1'b0;
    wire            wait_stb = is_waiting_in | is_repeating;
    wire [PC_W-1:0] pc;
    task_pc #(PC_W) tasks_pc_inst
    (
        .clk     (clk     ),
        .reset   (reset   ),
        .wait_stb(wait_stb),
        .jp_stb  (jp_stb  ),
        .jp_addr (jp_addr ),
        .pc_out  (pc      )
    );


    // REPEAT
    wire repeat_stb = task_repeat;
    wire [CCNT_W-1:0] repeat_cnt = CCNT;
    wire is_repeating;
    wire is_repeat_done;
    task_repeat #(CCNT_W) task_repeat_inst (
        .clk         (clk           ),
        .reset       (reset         ),
        .repeat_stb  (repeat_stb    ),
        .repeat_cnt  (repeat_cnt    ),
        .is_repeating(is_repeating  ),
        .is_done     (is_repeat_done)
    );


    // INDEX REG I
    wire i_stb_load = task_mov_i_0;
    wire i_stb_inc  = task_inc_i;
    wire [CCNT_W-1:0] i_reg_in = 0;
    wire [CCNT_W-1:0] i_reg;
    task_idx_reg#(CCNT_W) idx_i_reg_inst (
        .clk     (clk       ),
        .reset   (reset     ),
        .stb_load(i_stb_load),
        .stb_inc (i_stb_inc ),
        .reg_in  (i_reg_in  ),
        .reg_out (i_reg     )
    );


    // INDEX REG J
    wire j_stb_load             = task_mov_j_xhead;
    wire j_stb_inc_circ         = task_inc_j_circ;
    wire j_stb_dec_circ         = 1'b0;
    wire [CCNT_W-1:0] j_max_val = CCNT-1;
    wire [CCNT_W-1:0] j_reg_in  = x_buf_head_cnt;
    wire [CCNT_W-1:0] j_reg;
    task_circ_idx_reg#(CCNT_W) circ_idx_j_reg_inst (
        .clk            (clk            ),
        .reset          (reset          ),
        .stb_load       (j_stb_load     ),
        .stb_inc_circ   (j_stb_inc_circ ),
        .stb_dec_circ   (j_stb_dec_circ ),
        .max_val        (j_max_val      ),
        .reg_in         (j_reg_in       ),
        .reg_out        (j_reg          )
    );


    // HEAD INDEX REG
    wire              x_head_idx_stb_load     = 1'b0;
    wire              x_head_idx_stb_inc_circ = 1'b0;
    wire              x_head_idx_stb_dec_circ = task_push_x;
    wire [CCNT_W-1:0] x_head_idx_max_val      = CCNT-1;
    wire [CCNT_W-1:0] x_head_idx_reg_in       = 0;
    wire [CCNT_W-1:0] x_head_idx_reg;
    task_circ_idx_reg#(CCNT_W) circ_idx_j_reg_inst (
        .clk            (clk                     ),
        .reset          (reset                   ),
        .stb_load       (x_head_idx_stb_load     ),
        .stb_inc_circ   (x_head_idx_stb_inc_circ ),
        .stb_dec_circ   (x_head_idx_stb_dec_circ ),
        .max_val        (x_head_idx_max_val      ),
        .reg_in         (x_head_idx_reg_in       ),
        .reg_out        (x_head_idx_reg          )
    );


    // RAM BUFFER FOR X
    wire               xbuf_wr      = task_push_x;
    wire [CCNT_W-1:0]  xbuf_wr_addr = x_head_idx_reg;
    wire [35:0]        xbuf_wr_data = {sample_in_reg_l, sample_in_reg_r};
    wire               xbuf_rd      = task_mac_ci_xj;
    wire [CCNT_W-1:0]  xbuf_rd_addr = j_reg;
    wire [35:0]        xbuf_rd_data;
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
    wire signed [17:0] xjl          = xbuf_rd_data[35:18];
    wire signed [17:0] xjr          = xbuf_rd_data[17:0];


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
            'h20   : begin ci <= 18'h01054; end
            'h21   : begin ci <= 18'h00B6A; end
            'h22   : begin ci <= 18'h006D5; end
            'h23   : begin ci <= 18'h002F0; end
            'h24   : begin ci <= 18'h3FFF7; end
            'h25   : begin ci <= 18'h3FDFF; end
            'h26   : begin ci <= 18'h3FCF9; end
            'h27   : begin ci <= 18'h3FCBE; end
            'h28   : begin ci <= 18'h3FD13; end
            'h29   : begin ci <= 18'h3FDBC; end
            'h2a   : begin ci <= 18'h3FE82; end
            'h2b   : begin ci <= 18'h3FF3B; end
            'h2c   : begin ci <= 18'h3FFCC; end
            'h2d   : begin ci <= 18'h0002B; end
            'h2e   : begin ci <= 18'h0005B; end
            'h2f   : begin ci <= 18'h00065; end
            'h30   : begin ci <= 18'h00058; end
            'h31   : begin ci <= 18'h00040; end
            'h32   : begin ci <= 18'h00027; end
            'h33   : begin ci <= 18'h00013; end
            'h34   : begin ci <= 18'h00006; end
            'h35   : begin ci <= 18'h3FFFF; end
            'h36   : begin ci <= 18'h3FFFE; end
            'h37   : begin ci <= 18'h3FFFE; end
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
