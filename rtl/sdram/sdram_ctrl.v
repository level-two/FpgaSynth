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
    input             clk                 ,
    input             reset               ,
                                          
    input             sdram_access        ,
    input             sdram_cmd_ready     ,
    output            sdram_cmd_accepted  ,
    output            sdram_cmd_done      ,
    input  [31:0]     sdram_addr          ,
    input             sdram_wr_nrd        ,
    input  [15:0]     sdram_wr_data       ,
    output [15:0]     sdram_rd_data       ,
    //input           sdram_op_err        , // TBI

    // INTERFACE TO SDRAM
    output            sdram_clk           ,
    output reg        sdram_cke           ,
    output reg        sdram_ncs           ,
    output reg        sdram_ncas          ,
    output reg        sdram_nras          ,
    output reg        sdram_nwe           ,
    output reg        sdram_dqml          ,
    output reg        sdram_dqmh          ,
    output reg [12:0] sdram_a             ,
    output reg [ 1:0] sdram_ba            ,
    inout      [15:0] sdram_dq            ,

    // CSR
    input [0:0] csr_ctrl_start              ,
    input [0:0] csr_ctrl_self_refresh       , // TODO
    input [0:0] csr_ctrl_load_mode_register ,

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
    input [ 1:0] csr_t_wrp_val,
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
    localparam ST_RESET               = 'h00;
    localparam ST_IDLE                = 'h01;
    localparam ST_100US_DLY_AFTER_RST = 'h02;
    localparam ST_WAIT_INIT           = 'h03;
    localparam ST_INIT_NOP            = 'h04;
    localparam ST_INIT_PRECHG_ALL     = 'h05;
    localparam ST_INIT_AUTOREFR1      = 'h06;
    localparam ST_INIT_AUTOREFR2      = 'h07;
    localparam ST_CMD_LMR             = 'h08;
    localparam ST_CMD_AUTOREFRESH     = 'h09;
    localparam ST_CMD_ACTIVE          = 'h0a;
    localparam ST_CMD_READ            = 'h0b;
    localparam ST_CMD_WRITE           = 'h0c;
    localparam ST_CMD_PRECHARGE_ALL   = 'h0d;
    localparam ST_READ_TO_IDLE        = 'h0e;
    localparam ST_READ_TO_WRITE       = 'h0f;
    localparam ST_WRITE_TO_IDLE       = 'h10;
    localparam ST_RW_IDLE             = 'h11;

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
                // use sdram_cmd_ready instead of sdram_access to ensure
                // that there is valid address for ACTIVE command
                next_state = csr_ctrl_start        ? ST_INIT_NOP        :
                             need_autorefresh      ? ST_CMD_AUTOREFRESH :
                             csr_ctrl_load_mode_register ? ST_CMD_LMR   :
                             sdram_cmd_ready       ? ST_CMD_ACTIVE      :
                                                     ST_IDLE            ;
            end
            ST_CMD_LMR: begin
                if (timer_done) next_state = ST_IDLE;
            end
            ST_CMD_AUTOREFRESH: begin
                if (timer_done) next_state = ST_IDLE;
            end
            ST_CMD_ACTIVE: begin
                next_state = !timer_done   ? ST_CMD_ACTIVE :
                              sdram_wr_nrd ? ST_CMD_WRITE  :
                                             ST_CMD_READ   ;
            end
            ST_CMD_READ: begin
                // TODO In case of AUTOPRECHARGE after RD or WR operation
                // deissue turn to WAIT_AUTOPRECHARGE_DONE sate
                next_state = 
                    sdram_cmd_ready && !sdram_wr_nrd ? ST_CMD_READ      :
                    sdram_cmd_ready &&  sdram_wr_nrd ? ST_READ_TO_WRITE :
                                                       ST_READ_TO_IDLE  ;
            end
            ST_CMD_WRITE: begin
                // TODO In case of AUTOPRECHARGE after RD or WR operation
                // deissue turn to WAIT_AUTOPRECHARGE_DONE sate
                next_state =
                    sdram_cmd_ready &&  sdram_wr_nrd ? ST_CMD_WRITE     :
                    sdram_cmd_ready && !sdram_wr_nrd ? ST_CMD_READ      :
                    (csr_t_wrp_val == 1)             ? ST_RW_IDLE       :
                                                       ST_WRITE_TO_IDLE ;
            end
            ST_READ_TO_IDLE: begin
                    next_state = 
                        sdram_cmd_ready && !sdram_wr_nrd ? ST_CMD_READ      :
                        sdram_cmd_ready &&  sdram_wr_nrd ? ST_READ_TO_WRITE :
                        timer_done                       ? ST_RW_IDLE       :
                                                           ST_READ_TO_IDLE  ;
            end
            ST_READ_TO_WRITE: begin
                next_state =
                    timer_done ? ST_CMD_WRITE     :
                                 ST_READ_TO_WRITE ;
            end
            ST_WRITE_TO_IDLE: begin
                next_state = 
                     sdram_cmd_ready && !sdram_wr_nrd ? ST_CMD_READ      :
                     sdram_cmd_ready &&  sdram_wr_nrd ? ST_CMD_WRITE     :
                     timer_done                       ? ST_RW_IDLE       :
                                                        ST_WRITE_TO_IDLE ;
            end
            ST_RW_IDLE: begin
                next_state = 
                     sdram_cmd_ready && !sdram_wr_nrd ? ST_CMD_READ          :
                     sdram_cmd_ready &&  sdram_wr_nrd ? ST_CMD_WRITE         :
                     !sdram_access                    ? ST_CMD_PRECHARGE_ALL :
                                                        ST_RW_IDLE           ;
            end
            ST_CMD_PRECHARGE_ALL: begin
                if (timer_done) next_state = ST_IDLE;
            end
            default: begin
                next_state = ST_IDLE;
            end
        endcase
    end


    wire [31:0] timer_cnt_val = 
        (next_state == ST_100US_DLY_AFTER_RST) ? csr_t_dly_rst_val      :
        (next_state == ST_INIT_PRECHG_ALL    ) ? csr_t_rp_val           :
        (next_state == ST_INIT_AUTOREFR1     ) ? csr_t_rfc_val          :
        (next_state == ST_INIT_AUTOREFR2     ) ? csr_t_rfc_val          :
        (next_state == ST_CMD_AUTOREFRESH    ) ? csr_t_rfc_val          :
        (next_state == ST_CMD_LMR            ) ? csr_t_mrd_val          :
        (next_state == ST_CMD_ACTIVE         ) ? csr_t_rcd_val          :
        (next_state == ST_CMD_PRECHARGE_ALL  ) ? csr_t_rp_val           :
        (next_state == ST_READ_TO_IDLE       ) ? csr_opmode_cas_latency :
        (next_state == ST_READ_TO_WRITE      ) ? csr_opmode_cas_latency :
        (next_state == ST_WRITE_TO_IDLE      ) ? csr_t_wrp_val-1        :
        0;

    reg [31:0] timer_cnt;
    //wire timer_start   = (timer_cnt_val != 0 && timer_cnt == timer_cnt_val);
    //wire timer_running = (timer_cnt_val != 0 && timer_cnt != 0            );
    //wire timer_done    = (timer_cnt_val != 0 && timer_cnt == 1            );
    reg  timer_start;
    reg  timer_running;
    wire timer_done = (timer_cnt == 1);
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            timer_cnt     <= 'h0;
            timer_start   <= 1'b0;
            timer_running <= 1'b0;
        end
        else if (next_state != state) begin
            timer_cnt     <= timer_cnt_val;
            timer_start   <= |timer_cnt_val;
            timer_running <= |timer_cnt_val;
        end
        else if (timer_cnt != 0) begin
            timer_cnt     <= timer_cnt - 'h1;
            timer_start   <= 1'b0;
            timer_running <= 1'b1;
        end
        else begin
            timer_start   <= 1'b0;
            timer_running <= 1'b0;
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
            rd_data_valid      <= 3'b0;
        end
        else if (csr_t_cl_val == 3) begin
            rd_data_valid[2]   <= (state == ST_CMD_READ);
            rd_data_valid[1:0] <= rd_data_valid[2:1];
        end
        else if (csr_t_cl_val == 2) begin
            rd_data_valid[2]   <= 1'b0;
            rd_data_valid[1]   <= (state == ST_CMD_READ);
            rd_data_valid[0]   <= rd_data_valid[1];
        end
    end

    // SDRAM SIGNALS DRIVE
    assign sdram_clk          = clk;
    assign sdram_cmd_accepted = (next_state == ST_CMD_READ ||
                                 next_state == ST_CMD_WRITE);
    assign sdram_dq           = (state == ST_CMD_WRITE) ? sdram_wr_data : 16'hzzzz;
    assign sdram_rd_data      = rd_data_valid[0] ? sdram_dq : 16'h0000;
    assign sdram_cmd_done     = rd_data_valid[0] || state == ST_CMD_WRITE;


    always @(*) begin
        // INHIBIT
        sdram_cke  = #1 1'b1;
        sdram_ncs  = #1 1'b1;
        sdram_nras = #1 1'b1;
        sdram_ncas = #1 1'b1;
        sdram_nwe  = #1 1'b1;
        sdram_dqml = #1 1'b0;
        sdram_dqmh = #1 1'b0;
        sdram_a    = #1 13'h0;
        sdram_ba   = #1 2'h0;

        if (timer_running && !timer_start) begin
            // NOP
            sdram_ncs  = #1 1'b0;
        end
        else if (state == ST_IDLE || state == ST_WAIT_INIT) begin
            // INHIBIT
            // all signals are already set properly
        end
        else if (state == ST_INIT_PRECHG_ALL || state == ST_CMD_PRECHARGE_ALL) begin
            sdram_ncs   = #1 1'b0;
            sdram_nras  = #1 1'b0;
            sdram_ncas  = #1 1'b1;
            sdram_nwe   = #1 1'b0;
            sdram_a[10] = #1 1'b1; // 0 - pchg bank selected by sdram_ba; 1 - all (Note 5, p.31)
        end
        else if (state == ST_INIT_AUTOREFR1 ||
                 state == ST_INIT_AUTOREFR2 ||
                 state == ST_CMD_AUTOREFRESH)
        begin
            sdram_cke   = #1 1'b1;
            sdram_ncs   = #1 1'b0;
            sdram_nras  = #1 1'b0;
            sdram_ncas  = #1 1'b0;
            sdram_nwe   = #1 1'b1;
        end
        else if (state == ST_CMD_LMR) begin
            sdram_ncs   = #1 1'b0;
            sdram_nras  = #1 1'b0;
            sdram_ncas  = #1 1'b0;
            sdram_nwe   = #1 1'b0;
            sdram_ba    = #1 csr_opmode_ba_reserved[1:0];
            sdram_a[12:0] = #1 { 
                csr_opmode_a_reserved[2:0],
                csr_opmode_wr_burst_mode[0],
                csr_opmode_operation_mode[1:0],
                csr_opmode_cas_latency[2:0],
                csr_opmode_burst_type[0],
                csr_opmode_burst_len[2:0]
            };
        end
        else if (state == ST_CMD_ACTIVE) begin
            sdram_ncs     = #1 1'b0;
            sdram_nras    = #1 1'b0;
            sdram_ncas    = #1 1'b1;
            sdram_nwe     = #1 1'b1;
            sdram_a[12:0] = #1 sdram_addr[24:11];  // Row addr
            sdram_ba      = #1 sdram_addr[10:9];   // Bank addr
        end
        else if (state == ST_CMD_READ) begin
            sdram_ncs    = #1 1'b0;
            sdram_nras   = #1 1'b1;
            sdram_ncas   = #1 1'b0;
            sdram_nwe    = #1 1'b1;
            sdram_ba     = #1 sdram_addr[10:9];   // Bank addr
            sdram_a[8:0] = #1 sdram_addr[8:0];    // Col addr
            sdram_a[10]  = #1 csr_config_prechg_after_rd;
        end
        else if (state == ST_CMD_WRITE) begin
            sdram_ncs    = #1 1'b0;
            sdram_nras   = #1 1'b1;
            sdram_ncas   = #1 1'b0;
            sdram_nwe    = #1 1'b0;
            sdram_ba     = #1 sdram_addr[10:9];   // Bank addr
            sdram_a[8:0] = #1 sdram_addr[8:0];    // Col addr
            sdram_a[10]  = #1 csr_config_prechg_after_rd;
        end
        else if (state == ST_READ_TO_IDLE  ||
                 state == ST_READ_TO_WRITE ||
                 state == ST_WRITE_TO_IDLE ||
                 state == ST_RW_IDLE       ) begin
            // NOP
            sdram_ncs   = #1 1'b0;
            sdram_nras  = #1 1'b1;
            sdram_ncas  = #1 1'b1;
            sdram_nwe   = #1 1'b1;
        end
        else begin
            // NOP
            sdram_ncs   = #1 1'b0;
            sdram_nras  = #1 1'b1;
            sdram_ncas  = #1 1'b1;
            sdram_nwe   = #1 1'b1;
        end
    end
endmodule
