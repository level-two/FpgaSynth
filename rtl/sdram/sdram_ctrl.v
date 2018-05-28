// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: sdram_ctrl.v
// Description: Sdram controller
// -----------------------------------------------------------------------------
//       From page 37 of MT48LC16M16A2 datasheet
//       Name (Function)       CS# RAS# CAS# WE# DQM  Addr    Data
//       COMMAND INHIBIT (NOP)  H   X    X    X   X     X       X
//       NO OPERATION (NOP)     L   H    H    H   X     X       X
//       ACTIVE                 L   L    H    H   X  Bank/row   X
//       READ                   L   H    L    H  L/H Bank/col   X
//       WRITE                  L   H    L    L  L/H Bank/col Valid
//       BURST TERMINATE        L   H    H    L   X     X     Active
//       PRECHARGE              L   L    H    L   X   Code      X
//       AUTO REFRESH           L   L    L    H   X     X       X 
//       LOAD MODE REGISTER     L   L    L    L   X  Op-code    X 
//       Write enable           X   X    X    X   L     X     Active
//       Write inhibit          X   X    X    X   H     X     High-Z
// -----------------------------------------------------------------------------


module sdram_ctrl (
    input             clk                 ,
    input             reset               ,
                                          
    input             sdram_ctrl_access        ,
    input             sdram_ctrl_cmd_ready     ,
    output            sdram_ctrl_cmd_accepted  ,
    output reg        sdram_ctrl_cmd_done      ,
    input  [31:0]     sdram_ctrl_addr          ,
    input             sdram_ctrl_wr_nrd        ,
    input  [15:0]     sdram_ctrl_wr_data       ,
    output reg [15:0] sdram_ctrl_rd_data       ,
    //input           sdram_ctrl_op_err        , // TBI

    // INTERFACE TO SDRAM
    output            sdram_if_clk           ,
    output reg        sdram_if_cke           ,
    output reg        sdram_if_ncs           ,
    output reg        sdram_if_ncas          ,
    output reg        sdram_if_nras          ,
    output reg        sdram_if_nwe           ,
    output reg        sdram_if_dqml          ,
    output reg        sdram_if_dqmh          ,
    output reg [12:0] sdram_if_a             ,
    output reg [ 1:0] sdram_if_ba            ,
    inout      [15:0] sdram_if_dq            ,

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

    input [ 7:0] csr_t_rcd_val,
    input [ 7:0] csr_t_rfc_val,
    input [ 9:0] csr_t_ref_min_val,
    input [ 7:0] csr_t_rp_val,
    input [ 1:0] csr_t_wrp_val,

    input [ 3:0] csr_t_mrd_val
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
    localparam ST_READ_TO_PRECHARGE   = 'h12;
    localparam ST_WRITE_TO_PRECHARGE  = 'h13;

    reg [4:0] state;
    reg [4:0] next_state;
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
                // TODO: Check whether autorefresh is not counted before init
                //if (csr_ctrl_start) next_state = ST_INIT_NOP;
                next_state = ST_INIT_NOP;
            end
            ST_INIT_NOP: begin
                next_state = ST_INIT_PRECHG_ALL;
            end
            ST_INIT_PRECHG_ALL: begin
                if (timer_done) next_state = ST_INIT_AUTOREFR1; // ST_CMD_LMR;
            end
            ST_INIT_AUTOREFR1: begin
                if (timer_done) next_state = ST_INIT_AUTOREFR2;
            end
            ST_INIT_AUTOREFR2: begin
                if (timer_done) next_state = ST_CMD_LMR;
            end
            ST_IDLE: begin
                next_state = csr_ctrl_start               ? ST_INIT_NOP        :
                             csr_ctrl_load_mode_register  ? ST_CMD_LMR         :
                             sdram_ctrl_cmd_ready         ? ST_CMD_ACTIVE      :
                             (autorefresh_cycle_cnt != 0) ? ST_CMD_AUTOREFRESH :
                                                            ST_IDLE            ;
            end
            ST_CMD_LMR: begin
                if (timer_done) next_state = ST_IDLE;
            end
            ST_CMD_AUTOREFRESH: begin
                if (timer_done) next_state = ST_IDLE;
            end
            ST_CMD_ACTIVE: begin
                next_state = !timer_done        ? ST_CMD_ACTIVE :
                              sdram_ctrl_wr_nrd ? ST_CMD_WRITE  :
                                                  ST_CMD_READ   ;
            end
            ST_CMD_READ: begin
                next_state = 
                    row_bank_change                            ? ST_READ_TO_PRECHARGE  :
                    sdram_ctrl_cmd_ready && !sdram_ctrl_wr_nrd ? ST_CMD_READ           :
                    sdram_ctrl_cmd_ready &&  sdram_ctrl_wr_nrd ? ST_READ_TO_WRITE      :
                                                                 ST_READ_TO_IDLE       ;
            end
            ST_CMD_WRITE: begin
                next_state =
                    row_bank_change && csr_t_wrp_val == 1      ? ST_CMD_PRECHARGE_ALL  :
                    row_bank_change                            ? ST_WRITE_TO_PRECHARGE :
                    sdram_ctrl_cmd_ready && !sdram_ctrl_wr_nrd ? ST_CMD_READ           :
                    sdram_ctrl_cmd_ready &&  sdram_ctrl_wr_nrd ? ST_CMD_WRITE          :
                    (csr_t_wrp_val == 1)                       ? ST_RW_IDLE            :
                                                                 ST_WRITE_TO_IDLE      ;
            end
            ST_READ_TO_IDLE: begin
                next_state = 
                    row_bank_change                            ? ST_READ_TO_PRECHARGE  :
                    sdram_ctrl_cmd_ready && !sdram_ctrl_wr_nrd ? ST_CMD_READ           :
                    sdram_ctrl_cmd_ready &&  sdram_ctrl_wr_nrd ? ST_READ_TO_WRITE      :
                    timer_done                                 ? ST_RW_IDLE            :
                                                                 ST_READ_TO_IDLE       ;
            end
            ST_READ_TO_PRECHARGE: begin
                if (timer_done) next_state = ST_CMD_PRECHARGE_ALL;
            end
            ST_READ_TO_WRITE: begin
                if (timer_done) next_state = ST_CMD_WRITE;
            end
            ST_WRITE_TO_IDLE: begin
                next_state = 
                    row_bank_change                            ? ST_CMD_PRECHARGE_ALL :
                    sdram_ctrl_cmd_ready && !sdram_ctrl_wr_nrd ? ST_CMD_READ          :
                    sdram_ctrl_cmd_ready &&  sdram_ctrl_wr_nrd ? ST_CMD_WRITE         :
                                                                 ST_RW_IDLE           ;
            end
            ST_WRITE_TO_PRECHARGE: begin
                next_state = ST_CMD_PRECHARGE_ALL;
            end
            ST_RW_IDLE: begin
                next_state = 
                     row_bank_change                            ? ST_CMD_PRECHARGE_ALL :
                     sdram_ctrl_cmd_ready && !sdram_ctrl_wr_nrd ? ST_CMD_READ          :
                     sdram_ctrl_cmd_ready &&  sdram_ctrl_wr_nrd ? ST_CMD_WRITE         :
                     !sdram_ctrl_access                         ? ST_CMD_PRECHARGE_ALL :
                                                                  ST_RW_IDLE           ;
            end
            ST_CMD_PRECHARGE_ALL: begin
                next_state = !timer_done     ? ST_CMD_PRECHARGE_ALL :
                             row_bank_change ? ST_CMD_ACTIVE        :
                                               ST_IDLE              ;
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
        (next_state == ST_READ_TO_PRECHARGE  ) ? csr_opmode_cas_latency :
        (next_state == ST_READ_TO_WRITE      ) ? (csr_opmode_cas_latency == 3'h2 ? 4 : 5) :
        0;

    reg [31:0] timer_cnt;
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


    reg [9:0] autorefresh_timer;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            autorefresh_timer <= 'h0;
        end
        else if (state == ST_INIT_AUTOREFR2) begin
            autorefresh_timer <= 'h0;
        end
        else if (autorefresh_timer != 0) begin
            autorefresh_timer <= autorefresh_timer - 'h1;
        end
        else begin
            autorefresh_timer <= csr_t_ref_min_val;
        end
    end

    reg [10:0] autorefresh_cycle_cnt;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            autorefresh_cycle_cnt  <= 'h0;
        end
        else if (state == ST_INIT_AUTOREFR2) begin
            autorefresh_cycle_cnt  <= 'h0;
        end
        else if (autorefresh_timer == 0) begin
            autorefresh_cycle_cnt  <= autorefresh_cycle_cnt + 1;
        end
        else if (state == ST_CMD_AUTOREFRESH && timer_start) begin
            autorefresh_cycle_cnt  <= autorefresh_cycle_cnt - 1;
        end
    end

    reg [3:0] rd_data_valid;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rd_data_valid[3:0] <= 4'b0;
        end
        else if (csr_opmode_cas_latency == 3'h3) begin
            rd_data_valid[3]   <= (state == ST_CMD_READ);
            rd_data_valid[2]   <= rd_data_valid[3];
            rd_data_valid[1]   <= rd_data_valid[2];
            rd_data_valid[0]   <= rd_data_valid[1];
        end
        else if (csr_opmode_cas_latency == 3'h2) begin
            rd_data_valid[3]   <= 1'b0;
            rd_data_valid[2]   <= (state == ST_CMD_READ);
            rd_data_valid[1]   <= rd_data_valid[2];
            rd_data_valid[0]   <= rd_data_valid[1];
        end
    end


    reg [31:0] cur_sdram_addr;
    reg [15:0] cur_sdram_wr_data;
    always @(posedge clk) begin
        if (reset) begin
            cur_sdram_addr    <= 32'h0;
            cur_sdram_wr_data <= 16'h0;
        end
        else if (next_state == ST_CMD_READ || next_state == ST_CMD_WRITE) begin
            cur_sdram_addr    <= sdram_ctrl_addr;
            cur_sdram_wr_data <= sdram_ctrl_wr_data;
        end
    end

    wire row_bank_change = (sdram_ctrl_cmd_ready && sdram_ctrl_addr[24:9] != cur_sdram_addr[24:9]);


    // SDRAM SIGNALS DRIVE
    wire sdram_clk_ddr;

    ODDR2 #(
        .DDR_ALIGNMENT("NONE"                ),
        .INIT         (0                     ),
        .SRTYPE       ("SYNC"                )
    ) oddr2_inst (
        .CE  (1'b1                           ),
        .R   (1'b0                           ),
        .S   (1'b0                           ),
        //.D0  (1'b0                           ),
        //.D1  (1'b1                           ),
        .D0  (1'b1                           ),
        .D1  (1'b0                           ),
        .C0  (clk                            ),
        .C1  (~clk                           ),
        .Q   (sdram_clk_ddr                  )
    );

    IODELAY2 #(
        .IDELAY_VALUE(0                ),
        .IDELAY_MODE ("NORMAL"         ),
        .ODELAY_VALUE(38               ),
        //.ODELAY_VALUE(63               ), // value of 100 seems to work at 100MHz
        .IDELAY_TYPE ("FIXED"          ),
        .DELAY_SRC   ("ODATAIN"        ),
        .DATA_RATE   ("SDR"            )
    ) IODELAY_inst   (
        .IDATAIN     (1'b0             ),
        .T           (1'b0             ),
        .ODATAIN     (sdram_clk_ddr    ),
        .CAL         (1'b0             ),
        .IOCLK0      (1'b0             ),
        .IOCLK1      (1'b0             ),
        .CLK         (1'b0             ),
        .INC         (1'b0             ),
        .CE          (1'b0             ),
        .RST         (1'b0             ),
        .BUSY        (                 ),
        .DATAOUT     (                 ),
        .DATAOUT2    (                 ),
        .TOUT        (                 ),
        .DOUT        (sdram_if_clk     )
    );

    assign sdram_ctrl_cmd_accepted = (next_state == ST_CMD_READ ||
                                      next_state == ST_CMD_WRITE);


    reg        sdram_if_cke_int;
    reg        sdram_if_ncs_int;
    reg        sdram_if_ncas_int;
    reg        sdram_if_nras_int;
    reg        sdram_if_nwe_int;
    //reg        sdram_if_dqml_int;
    //reg        sdram_if_dqmh_int;
    reg [12:0] sdram_if_a_int;
    reg [ 1:0] sdram_if_ba_int;


    always @(posedge clk) begin
        if (reset) begin
            sdram_ctrl_rd_data <= 16'h0000;
        end
        else if (rd_data_valid[0] == 1'b1) begin
            sdram_ctrl_rd_data <= sdram_if_dq;
        end
        else begin
            sdram_ctrl_rd_data <= 16'h0000;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            sdram_ctrl_cmd_done <= 1'b0;
        end
        else if (rd_data_valid[0] == 1'b1 || next_state == ST_CMD_WRITE) begin
            sdram_ctrl_cmd_done <= 1'b1;
        end
        else begin
            sdram_ctrl_cmd_done <= 1'b0;
        end
    end


    always @(*) begin
        // INHIBIT
        sdram_if_cke_int  = 1'b1;
        sdram_if_ncs_int  = 1'b1;
        sdram_if_nras_int = 1'b1;
        sdram_if_ncas_int = 1'b1;
        sdram_if_nwe_int  = 1'b1;
        sdram_if_a_int    = 13'h0;
        sdram_if_ba_int   = 2'h0;

        if (timer_running && !timer_start) begin
            // NOP
            sdram_if_ncs_int  = 1'b0;
        end
        else if (state == ST_IDLE || state == ST_WAIT_INIT) begin
            // INHIBIT
            // all signals are already set properly
        end
        else if (state == ST_INIT_PRECHG_ALL || state == ST_CMD_PRECHARGE_ALL) begin
            sdram_if_ncs_int   = 1'b0;
            sdram_if_nras_int  = 1'b0;
            sdram_if_ncas_int  = 1'b1;
            sdram_if_nwe_int   = 1'b0;
            sdram_if_a_int[10] = 1'b1; // 0 - pchg bank selected by sdram_if_ba_int; 1 - all (Note 5, p.31)
        end
        else if (state == ST_INIT_AUTOREFR1 ||
                 state == ST_INIT_AUTOREFR2 ||
                 state == ST_CMD_AUTOREFRESH) begin
            sdram_if_cke_int   = 1'b1;
            sdram_if_ncs_int   = 1'b0;
            sdram_if_nras_int  = 1'b0;
            sdram_if_ncas_int  = 1'b0;
            sdram_if_nwe_int   = 1'b1;
        end
        else if (state == ST_CMD_LMR) begin
            sdram_if_ncs_int   = 1'b0;
            sdram_if_nras_int  = 1'b0;
            sdram_if_ncas_int  = 1'b0;
            sdram_if_nwe_int   = 1'b0;
            sdram_if_ba_int    = csr_opmode_ba_reserved[1:0];
            sdram_if_a_int[12:0] = { 
                csr_opmode_a_reserved[2:0],
                csr_opmode_wr_burst_mode[0],
                csr_opmode_operation_mode[1:0],
                csr_opmode_cas_latency[2:0],
                csr_opmode_burst_type[0],
                csr_opmode_burst_len[2:0]
            };
        end
        else if (state == ST_CMD_ACTIVE) begin
            sdram_if_ncs_int     = 1'b0;
            sdram_if_nras_int    = 1'b0;
            sdram_if_ncas_int    = 1'b1;
            sdram_if_nwe_int     = 1'b1;
            sdram_if_a_int[12:0] = sdram_ctrl_addr[23:11];  // Row addr
            sdram_if_ba_int      = sdram_ctrl_addr[10:9];   // Bank addr
        end
        else if (state == ST_CMD_READ) begin
            sdram_if_ncs_int    = 1'b0;
            sdram_if_nras_int   = 1'b1;
            sdram_if_ncas_int   = 1'b0;
            sdram_if_nwe_int    = 1'b1;
            sdram_if_ba_int     = cur_sdram_addr[10:9];   // Bank addr
            sdram_if_a_int[8:0] = cur_sdram_addr[8:0];    // Col addr
            sdram_if_a_int[10]  = csr_config_prechg_after_rd;
        end
        else if (state == ST_CMD_WRITE) begin
            sdram_if_ncs_int    = 1'b0;
            sdram_if_nras_int   = 1'b1;
            sdram_if_ncas_int   = 1'b0;
            sdram_if_nwe_int    = 1'b0;
            sdram_if_ba_int     = cur_sdram_addr[10:9];   // Bank addr
            sdram_if_a_int[8:0] = cur_sdram_addr[8:0];    // Col addr
            sdram_if_a_int[10]  = csr_config_prechg_after_rd;
        end
        else if (state == ST_READ_TO_IDLE       ||
                 state == ST_WRITE_TO_IDLE      ||
                 state == ST_READ_TO_WRITE      ||
                 state == ST_READ_TO_PRECHARGE  ||
                 state == ST_WRITE_TO_PRECHARGE ||
                 state == ST_RW_IDLE             ) begin
            // NOP
            sdram_if_ncs_int   = 1'b0;
            sdram_if_nras_int  = 1'b1;
            sdram_if_ncas_int  = 1'b1;
            sdram_if_nwe_int   = 1'b1;
        end
        else begin
            // NOP
            sdram_if_ncs_int   = 1'b0;
            sdram_if_nras_int  = 1'b1;
            sdram_if_ncas_int  = 1'b1;
            sdram_if_nwe_int   = 1'b1;
        end
    end

    /*
    always @(*) begin
        sdram_if_dqml_int = 1'b0;
        sdram_if_dqmh_int = 1'b0;

        // TODO Check this!
        if (state == ST_READ_TO_WRITE) begin
            // DQM 2 cycles prior to WRITE
            sdram_if_dqml_int = ~rd_data_valid[3] & (rd_data_valid[2] | rd_data_valid[1]);
            sdram_if_dqmh_int = ~rd_data_valid[3] & (rd_data_valid[2] | rd_data_valid[1]);
        end
    end
    */

    reg [15:0] sdram_if_dq_reg;
    reg sdram_if_dq_en;

    always @(posedge clk) begin
        sdram_if_cke  <= sdram_if_cke_int;
        sdram_if_ncs  <= sdram_if_ncs_int;
        sdram_if_ncas <= sdram_if_ncas_int;
        sdram_if_nras <= sdram_if_nras_int;
        sdram_if_nwe  <= sdram_if_nwe_int;
        //sdram_if_dqml <= sdram_if_dqml_int;
        //sdram_if_dqmh <= sdram_if_dqmh_int;
        sdram_if_dqml <= 1'b0;
        sdram_if_dqmh <= 1'b0;
        sdram_if_a    <= sdram_if_a_int;
        sdram_if_ba   <= sdram_if_ba_int;
        sdram_if_dq_reg <= cur_sdram_wr_data;
        sdram_if_dq_en  <= (state == ST_CMD_WRITE);
    end

    // To solve error "Non-net port sdram_if_dq cannot be of mode inout"
    assign sdram_if_dq = sdram_if_dq_en ? sdram_if_dq_reg : 16'bz;

endmodule
