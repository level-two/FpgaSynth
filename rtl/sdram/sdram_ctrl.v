// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: sdram_ctrl.v
// Description: Sdram controller
// -----------------------------------------------------------------------------


module sdram_ctrl (
    input             clk           ,
    input             reset         ,

    // CONTROL INTERFACE
    input  [14:0]     sdram_addr    ,
    input             sdram_wr      ,
    input             sdram_rd      ,
    input  [15:0]     sdram_wr_data ,
    output [15:0]     sdram_rd_data ,
    output            sdram_op_done ,
    //output          sdram_op_err  , // TBI
    //output          sdram_busy    , // TBI

    // INTERFACE TO SDRAM
    output            sdram_clk     ,
    output reg        sdram_cke     ,
    output reg        sdram_ncs     ,
    output reg        sdram_ncas    ,
    output reg        sdram_nras    ,
    output reg        sdram_nwe     ,
    output reg        sdram_dqml    ,
    output reg        sdram_dqmh    ,
    output reg [12:0] sdram_a       ,
    output reg [ 1:0] sdram_ba      ,
    input      [15:0] sdram_dq      ,

    // CSR
    input [0:0] csr_ctrl_start              ,
    input [0:0] csr_ctrl_self_refresh       ,
    input [1:0] csr_opmode_ba_reserved      ,
    input [2:0] csr_opmode_a_reserved       ,
    input [0:0] csr_opmode_wr_burst_mode    ,
    input [1:0] csr_opmode_operation_mode   ,
    input [2:0] csr_opmode_cas_latency      ,
    input [0:0] csr_opmode_burst_type       ,
    input [2:0] csr_opmode_burst_len        ,

    input [19:0] csr_t_dly_rst_val,
    input [ 7:0] csr_t_ac_val,
    input [ 7:0] csr_t_ah_val,
    input [ 7:0] csr_t_as_val,
    input [ 7:0] csr_t_ch_val,
    input [ 7:0] csr_t_cl_val,
    input [ 7:0] csr_t_ck_val,
    input [ 7:0] csr_t_ckh_val,
    input [ 7:0] csr_t_cks_val,
    input [ 7:0] csr_t_cmh_val,
    input [ 7:0] csr_t_cms_val,
    input [ 7:0] csr_t_dh_val,
    input [ 7:0] csr_t_ds_val,
    input [ 7:0] csr_t_hz_val,
    input [ 7:0] csr_t_lz_val,
    input [ 7:0] csr_t_oh_val,
    input [ 7:0] csr_t_ohn_val,
    input [ 7:0] csr_t_rasmin_val,
    input [19:0] csr_t_rasmax_val,
    input [ 7:0] csr_t_rc_val,
    input [ 7:0] csr_t_rcd_val,
    input [19:0] csr_t_ref_val,
    input [ 7:0] csr_t_rfc_val,
    input [ 7:0] csr_t_rp_val,
    input [ 7:0] csr_t_rrd_val,
    input [ 7:0] csr_t_wrap_val,
    input [ 7:0] csr_t_wrp_val,
    input [ 7:0] csr_t_xsr_val,

    input [ 3:0] csr_r_t_bdl_val,
    input [ 3:0] csr_t_ccd_val,
    input [ 3:0] csr_t_cdl_val,
    input [ 3:0] csr_t_cked_val,
    input [ 3:0] csr_t_dal_val,
    input [ 3:0] csr_t_dpl_val,
    input [ 3:0] csr_t_dqd_val,
    input [ 3:0] csr_t_dqm_val,
    input [ 3:0] csr_t_dqz_val,
    input [ 3:0] csr_t_dwd_val,
    input [ 3:0] csr_t_mrd_val,
    input [ 3:0] csr_t_ped_val,
    input [ 3:0] csr_t_rdl_val,
    input [ 3:0] csr_t_roh_val
);

    // STATE MACHINE
    localparam ST_RESET               = 'h0;
    localparam ST_IDLE                = 'h1;
    localparam ST_100US_DLY_AFTER_RST = 'h2;
    localparam ST_WAIT_INIT           = 'h3;
    localparam ST_INIT_NOP            = 'h4;
    localparam ST_INIT_PRECHG_ALL     = 'h5;
    localparam ST_INIT_AUTOREFR1      = 'h6;
    localparam ST_INIT_AUTOREFR2      = 'h7;
    localparam ST_CMD_LMR             = 'h8;

    reg [31:0] state;
    reg [31:0] next_state;
    always @(posedge clk or posedge reset) begin
        if (reset) state <= ST_RESET;
        else       state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            ST_RESET: begin
                next_state = ST_100US_DLY_AFTER_RST;
            end
            ST_100US_DLY_AFTER_RST: begin
                if (timer_done) next_state = ST_WAIT_INIT;
            end
            ST_WAIT_INIT: begin
                if (csr_ctrl_start) next_state = ST_INIT_NOP;
            end
            ST_INIT_NOP: begin
                next_state = ST_INIT_PRECHG_ALL;
            end
            ST_INIT_PRECHG_ALL: begin
                if (timer_done) next_state = ST_INIT_AUTOREFR1;
            end
            ST_INIT_AUTOREFR1: begin
                if (timer_done) next_state = ST_INIT_AUTOREFR2;
            end
            ST_INIT_AUTOREFR2: begin
                if (timer_done) next_state = ST_CMD_LMR;
            end

            ST_IDLE: begin
                if (csr_ctrl_start) next_state = ST_INIT_NOP;
                //if (csr_load_mode_reg_req) next_state = ST_CMD_LMR;
            end
            ST_CMD_LMR: begin
                if (timer_done) next_state = ST_IDLE;
            end
            default: begin
                next_state = ST_IDLE;
            end
        endcase
    end


    reg [31:0] timer_cnt;
    wire timer_done        = (timer_cnt     == 32'b0 &&
                              timer_cnt_val != 32'b0);
    wire timer_in_progress = (timer_cnt     != timer_cnt_val &&
                              timer_cnt     != 32'b0 &&
                              timer_cnt_val != 32'b0);

    wire [31:0] timer_cnt_val = 
        (state == ST_100US_DLY_AFTER_RST) ? csr_t_dly_rst_val  :
        (state == ST_INIT_PRECHG_ALL    ) ? csr_t_rp_val       :
        (state == ST_INIT_AUTOREFR1     ) ? csr_t_rfc_val      :
        (state == ST_INIT_AUTOREFR2     ) ? csr_t_rfc_val      :
        (state == ST_CMD_LMR            ) ? csr_t_mrd_val      :
        32'h0;
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            timer_cnt <= 'h0;
        end
        else if (timer_cnt != 0) begin
            timer_cnt <= timer_cnt - 'h1;
        end
        else if (timer_cnt == 0 && next_state != state) begin
            timer_cnt <= timer_cnt_val;
        end
    end

    // SDRAM SIGNALS DRIVE
    assign sdram_clk = clk;

    always @(*) begin
        // INHIBIT
        sdram_cke  = 1'b1;
        sdram_ncs  = 1'b1;
        sdram_nras = 1'b1;
        sdram_ncas = 1'b1;
        sdram_nwe  = 1'b1;
        sdram_dqml = 1'b0;
        sdram_dqmh = 1'b0;
        sdram_a    = 13'h0;
        sdram_ba   = 2'h0;

        if (timer_in_progress || timer_done) begin
            // NOP
            sdram_ncs  = 1'b0;
        end
        else if (state == ST_IDLE || state == ST_WAIT_INIT) begin
            // INHIBIT
            // all signals are already set properly
        end
        else if (state == ST_INIT_PRECHG_ALL) begin
            sdram_ncs   = 1'b0;
            sdram_nras  = 1'b0;
            sdram_ncas  = 1'b1;
            sdram_nwe   = 1'b0;
            sdram_a[10] = 1'b1; // 0 - pchg bank selected by sdram_ba; 1 - all (Note 5, p.31)
        end
        else if (state == ST_INIT_AUTOREFR1 || state == ST_INIT_AUTOREFR2) begin
            sdram_cke   = 1'b1;
            sdram_ncs   = 1'b0;
            sdram_nras  = 1'b0;
            sdram_ncas  = 1'b0;
            sdram_nwe   = 1'b1;
        end
        else if (state == ST_CMD_LMR) begin
            sdram_ncs   = 1'b0;
            sdram_nras  = 1'b0;
            sdram_ncas  = 1'b0;
            sdram_nwe   = 1'b0;
            sdram_ba    = csr_opmode_ba_reserved[1:0];
            sdram_a[12:0] = { 
                csr_opmode_a_reserved[2:0],
                csr_opmode_wr_burst_mode[0],
                csr_opmode_operation_mode[1:0],
                csr_opmode_cas_latency[2:0],
                csr_opmode_burst_type[0],
                csr_opmode_burst_len[2:0]
            };
        end
        else begin
            // NOP
            sdram_ncs   = 1'b0;
            sdram_nras  = 1'b1;
            sdram_ncas  = 1'b1;
            sdram_nwe   = 1'b1;
        end
    end

    assign sdram_rd_data = sdram_dq; // TODO implement this functionality
    assign sdram_op_done = 1'b0;


endmodule
