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

    // WISHBONE SLAVE INTERFACE
    input  [31:0]     wbs_address   ,
    input  [15:0]     wbs_writedata ,
    output [15:0]     wbs_readdata  ,
    input             wbs_strobe    ,
    input             wbs_cycle     ,
    input             wbs_write     ,
    output            wbs_ack       ,
    output            wbs_stall     ,
    //output          wbs_err       , // TBI



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
    inout      [15:0] sdram_dq      ,

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
    
    input [0:0] csr_config_prechg_after_rd  ,


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
    input [ 9:0] csr_t_ref_min_val,
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

    // WISHBONE INTERFACE TODO
    reg  wb_trans_dly;
    wire wb_trans = wbs_strobe & wbs_cycle;

    always @(posedge clk or posedge reset) begin
        if (reset) wb_trans_dly <= 1'h0;
        else       wb_trans_dly <= wb_trans;
    end

    assign sdram_rd      = wb_trans & ~wb_trans_dly & ~wbs_write;
    assign sdram_wr      = wb_trans & ~wb_trans_dly & wbs_write;

    always @(posedge clk or posedge reset) begin
        if (reset) wb_ack <= 1'h0;
        else       wb_ack <= (rd_data_valid[0] || state == ST_CMD_WRITE);
    end




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
    localparam ST_CMD_AUTOREFRESH     = 'h9;
    localparam ST_CMD_ACTIVE          = 'ha;
    localparam ST_CMD_READ            = 'hb;
    localparam ST_CMD_WRITE           = 'hc;
    localparam ST_CMD_PRECHARGE_ALL   = 'hd;


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
                next_state = csr_ctrl_start        ? ST_INIT_NOP        :
                             need_autorefresh      ? ST_CMD_AUTOREFRESH :
                             csr_load_mode_reg_req ? ST_CMD_LMR         :
                             sdram_wr              ? ST_CMD_ACTIVE      :
                             sdram_rd              ? ST_CMD_ACTIVE      ;
            end

            ST_CMD_NOP: begin
                next_state = sdram_wr ? ST_CMD_WRITE :
                             sdram_rd ? ST_CMD_READ  :
                                        ST_CMD_NOP   ;
            end

            ST_CMD_LMR: begin
                if (timer_done) next_state = ST_IDLE;
            end

            ST_CMD_AUTOREFRESH: begin
                if (timer_done) next_state = ST_IDLE;
            end
            ST_CMD_ACTIVE: begin
                if (timer_done)
                    next_state = sdram_wr ? ST_CMD_WRITE :
                                 sdram_rd ? ST_CMD_READ  :
                                            ST_CMD_NOP   ;
            end

            ST_CMD_READ: begin
                next_state = sdram_wr ? ST_CMD_WRITE :
                             sdram_rd ? ST_CMD_READ  :
                                        ST_CMD_NOP   ;
            end
            ST_WRITE: begin
                next_state = sdram_wr ? ST_CMD_WRITE :
                             sdram_rd ? ST_CMD_READ  :
                                        ST_CMD_NOP   ;
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
        (state == ST_CMD_AUTOREFRESH    ) ? csr_t_rfc_val      :
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

    reg [31:0] autorefresh_timer;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            autorefresh_timer <= 'h0;
        end
        else if (autorefresh_timer != 0) begin
            autorefresh_timer <= autorefresh_timer - 'h1;
        end
        else begin
            autorefresh_timer <= csr_t_ref_min_val;
        end
    end

    reg need_autorefresh;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            need_autorefresh  <= 1'b0;
        end
        else if (autorefresh_timer == 0) begin
            need_autorefresh  <= 1'b1;
        end
        else if (state == ST_CMD_AUTOREFRESH) begin
            need_autorefresh  <= 1'b0;
        end
    end

    reg [2:0] rd_data_valid;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rd_data_valid <= 3'b0;
        end
        else if (csr_t_cl_val == 3) begin
            rd_data_valid[2]   <= (state == ST_CMD_READ);
            rd_data_valid[1:0] <= rd_data_valid[2:1];
        end
        else if (csr_t_cl_val == 2) begin
            rd_data_valid[1]   <= (state == ST_CMD_READ);
            rd_data_valid[0]   <= rd_data_valid[1];
        end
    end

    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            wbs_readdata <= 16'h0000;
            sdram_dq     <= 16'hzzzz;
        end
        else if (state == ST_CMD_WRITE) begin
            sdram_dq <= wbs_writedata;
        end
        else if (rd_data_valid[0]]) begin
            wbs_readdata <= sdram_dq;
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
        else if (state == ST_INIT_PRECHG_ALL || state == ST_CMD_PRECHARGE_ALL) begin
            sdram_ncs   = 1'b0;
            sdram_nras  = 1'b0;
            sdram_ncas  = 1'b1;
            sdram_nwe   = 1'b0;
            sdram_a[10] = 1'b1; // 0 - pchg bank selected by sdram_ba; 1 - all (Note 5, p.31)
        end
        else if (state == ST_INIT_AUTOREFR1 ||
                 state == ST_INIT_AUTOREFR2 ||
                 state == ST_CMD_AUTOREFRESH)
        begin
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
        else if (state == ST_CMD_ACTIVE) begin
            sdram_ncs     = 1'b0;
            sdram_nras    = 1'b0;
            sdram_ncas    = 1'b1;
            sdram_nwe     = 1'b1;
            sdram_a[12:0] = sdram_addr[24:11];  // Row addr
            sdram_ba      = sdram_addr[10:9];   // Bank addr
        end
        else if (state == ST_CMD_READ) begin
            sdram_ncs    = 1'b0;
            sdram_nras   = 1'b1;
            sdram_ncas   = 1'b0;
            sdram_nwe    = 1'b1;
            sdram_ba     = sdram_addr[10:9];   // Bank addr
            sdram_a[8:0] = sdram_addr[8:0];    // Col addr
            sdram_a[10]  = csr_config_prechg_after_rd;
            sdram_dqml   = 1'b1;
            sdram_dqmh   = 1'b1;
        end
        else if (state == ST_CMD_WRITE) begin
            sdram_ncs    = 1'b0;
            sdram_nras   = 1'b1;
            sdram_ncas   = 1'b0;
            sdram_nwe    = 1'b0;
            sdram_ba     = sdram_addr[10:9];   // Bank addr
            sdram_a[8:0] = sdram_addr[8:0];    // Col addr
            sdram_a[10]  = csr_config_prechg_after_rd;
            sdram_dqml   = 1'b1;
            sdram_dqmh   = 1'b1;
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
