// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: sdram_top.v
// Description: Top level for SDRAM driver hierarchy
// -----------------------------------------------------------------------------


module sdram_top (
    input                      clk                 ,
    input                      reset               ,

    // WISHBONE SLAVE INTERFACE FOR CSR
    input  [AW_CSR-1:0]        wbs_csr_address     ,
    input  [31:0]              wbs_csr_writedata   ,
    output [31:0]              wbs_csr_readdata    ,
    input                      wbs_csr_strobe      ,
    input                      wbs_csr_cycle       ,
    input                      wbs_csr_write       ,
    output                     wbs_csr_ack         ,

    // WISHBONE SLAVE INTERFACE FOR SDRAM ACCESS
    input  [31:0]              wbs_sdram_address   ,
    input  [15:0]              wbs_sdram_writedata ,
    output [15:0]              wbs_sdram_readdata  ,
    input                      wbs_sdram_strobe    ,
    input                      wbs_sdram_cycle     ,
    input                      wbs_sdram_write     ,
    output                     wbs_sdram_ack       ,
    output                     wbs_sdram_stall     ,
    //output                   wbs_sdram_err       , // TBI

    // INTERFACE TO SDRAM
    output                     sdram_if_clk        ,
    output                     sdram_if_cke        ,
    output                     sdram_if_ncs        ,
    output                     sdram_if_ncas       ,
    output                     sdram_if_nras       ,
    output                     sdram_if_nwe        ,
    output                     sdram_if_dqml       ,
    output                     sdram_if_dqmh       ,
    output [12:0]              sdram_if_a          ,
    output [ 1:0]              sdram_if_ba         ,
    inout  [15:0]              sdram_if_dq
);

    parameter AW_CSR   = 16;

    wire        sdram_ctrl_access;
    wire        sdram_ctrl_cmd_ready;
    wire        sdram_ctrl_cmd_accepted;
    wire        sdram_ctrl_cmd_done;
    wire [31:0] sdram_ctrl_addr;
    wire        sdram_ctrl_wr_nrd;
    wire [15:0] sdram_ctrl_wr_data;
    wire [15:0] sdram_ctrl_rd_data;
    //wire      sdram_ctrl_op_err; // TBI

    sdram_wb sdram_wb_inst (
        .clk                        (clk                        ),
        .reset                      (reset                      ),

        // WISHBONE SLAVE INTERFACE
        .wbs_address                (wbs_sdram_address          ),
        .wbs_writedata              (wbs_sdram_writedata        ),
        .wbs_readdata               (wbs_sdram_readdata         ),
        .wbs_strobe                 (wbs_sdram_strobe           ),
        .wbs_cycle                  (wbs_sdram_cycle            ),
        .wbs_write                  (wbs_sdram_write            ),
        .wbs_ack                    (wbs_sdram_ack              ),
        .wbs_stall                  (wbs_sdram_stall            ),
        //.wbs_err                  (wbs_sdram_err              ), // TBI
                                                                
        .sdram_ctrl_addr            (sdram_ctrl_addr            ),
        .sdram_ctrl_wr_nrd          (sdram_ctrl_wr_nrd          ),
        .sdram_ctrl_cmd_ready       (sdram_ctrl_cmd_ready       ),
        .sdram_ctrl_cmd_accepted    (sdram_ctrl_cmd_accepted    ),
        .sdram_ctrl_cmd_done        (sdram_ctrl_cmd_done        ),
        .sdram_ctrl_wr_data         (sdram_ctrl_wr_data         ),
        .sdram_ctrl_rd_data         (sdram_ctrl_rd_data         ),
        .sdram_ctrl_access          (sdram_ctrl_access          )
        //.sdram_ctrl_op_err        (sdram_ctrl_op_err          ) 
    );

    wire[ 0:0] csr_ctrl_start;
    wire[ 0:0] csr_ctrl_self_refresh;
    wire[ 0:0] csr_ctrl_load_mode_register;
    wire[ 1:0] csr_opmode_ba_reserved;
    wire[ 2:0] csr_opmode_a_reserved;
    wire[ 0:0] csr_opmode_wr_burst_mode;
    wire[ 1:0] csr_opmode_operation_mode;
    wire[ 2:0] csr_opmode_cas_latency;
    wire[ 0:0] csr_opmode_burst_type;
    wire[ 2:0] csr_opmode_burst_len;
    wire[ 0:0] csr_config_prechg_after_rd;
    wire[19:0] csr_t_dly_rst_val;
    wire[ 7:0] csr_t_rcd_val;
    wire[ 7:0] csr_t_rfc_val;
    wire[ 9:0] csr_t_ref_min_val;
    wire[ 7:0] csr_t_rp_val;
    wire[ 1:0] csr_t_wrp_val;
    wire[ 3:0] csr_t_mrd_val;

    sdram_csr#(.AW(AW_CSR)) sdram_csr_inst
    (
        .clk                        (clk                        ),
        .reset                      (reset                      ),

        .wbs_address                (wbs_csr_address            ),
        .wbs_writedata              (wbs_csr_writedata          ),
        .wbs_readdata               (wbs_csr_readdata           ),
        .wbs_strobe                 (wbs_csr_strobe             ),
        .wbs_cycle                  (wbs_csr_cycle              ),
        .wbs_write                  (wbs_csr_write              ),
        .wbs_ack                    (wbs_csr_ack                ),

        // CSR
        .csr_ctrl_start             (csr_ctrl_start             ),
        .csr_ctrl_self_refresh      (csr_ctrl_self_refresh      ),
        .csr_ctrl_load_mode_register(csr_ctrl_load_mode_register),
        .csr_opmode_ba_reserved     (csr_opmode_ba_reserved     ),
        .csr_opmode_a_reserved      (csr_opmode_a_reserved      ),
        .csr_opmode_wr_burst_mode   (csr_opmode_wr_burst_mode   ),
        .csr_opmode_operation_mode  (csr_opmode_operation_mode  ),
        .csr_opmode_cas_latency     (csr_opmode_cas_latency     ),
        .csr_opmode_burst_type      (csr_opmode_burst_type      ),
        .csr_opmode_burst_len       (csr_opmode_burst_len       ),
        .csr_config_prechg_after_rd (csr_config_prechg_after_rd ),
        .csr_t_dly_rst_val          (csr_t_dly_rst_val          ),
        .csr_t_rcd_val              (csr_t_rcd_val              ),
        .csr_t_rfc_val              (csr_t_rfc_val              ),
        .csr_t_ref_min_val          (csr_t_ref_min_val          ),
        .csr_t_rp_val               (csr_t_rp_val               ),
        .csr_t_wrp_val              (csr_t_wrp_val              ),
        .csr_t_mrd_val              (csr_t_mrd_val              )
    );

    sdram_ctrl sdram_ctrl_inst (
        .clk                        (clk                        ),
        .reset                      (reset                      ),
                                                                
        .sdram_ctrl_access          (sdram_ctrl_access           ),
        .sdram_ctrl_cmd_ready       (sdram_ctrl_cmd_ready        ),
        .sdram_ctrl_cmd_accepted    (sdram_ctrl_cmd_accepted     ),
        .sdram_ctrl_cmd_done        (sdram_ctrl_cmd_done         ),
        .sdram_ctrl_addr            (sdram_ctrl_addr             ),
        .sdram_ctrl_wr_nrd          (sdram_ctrl_wr_nrd           ),
        .sdram_ctrl_wr_data         (sdram_ctrl_wr_data          ),
        .sdram_ctrl_rd_data         (sdram_ctrl_rd_data          ),
        //.sdram_ctrl_op_err        (sdram_ctrl_op_err               ),
                                                                
        .sdram_if_clk               (sdram_if_clk               ),
        .sdram_if_cke               (sdram_if_cke               ),
        .sdram_if_ncs               (sdram_if_ncs               ),
        .sdram_if_ncas              (sdram_if_ncas              ),
        .sdram_if_nras              (sdram_if_nras              ),
        .sdram_if_nwe               (sdram_if_nwe               ),
        .sdram_if_dqml              (sdram_if_dqml              ),
        .sdram_if_dqmh              (sdram_if_dqmh              ),
        .sdram_if_a                 (sdram_if_a                 ),
        .sdram_if_ba                (sdram_if_ba                ),
        .sdram_if_dq                (sdram_if_dq                ),

        // CSR
        .csr_ctrl_start             (csr_ctrl_start             ),
        .csr_ctrl_self_refresh      (csr_ctrl_self_refresh      ),
        .csr_ctrl_load_mode_register(csr_ctrl_load_mode_register),
        .csr_opmode_ba_reserved     (csr_opmode_ba_reserved     ),
        .csr_opmode_a_reserved      (csr_opmode_a_reserved      ),
        .csr_opmode_wr_burst_mode   (csr_opmode_wr_burst_mode   ),
        .csr_opmode_operation_mode  (csr_opmode_operation_mode  ),
        .csr_opmode_cas_latency     (csr_opmode_cas_latency     ),
        .csr_opmode_burst_type      (csr_opmode_burst_type      ),
        .csr_opmode_burst_len       (csr_opmode_burst_len       ),
        .csr_config_prechg_after_rd (csr_config_prechg_after_rd ),
        .csr_t_dly_rst_val          (csr_t_dly_rst_val          ),
        .csr_t_rcd_val              (csr_t_rcd_val              ),
        .csr_t_rfc_val              (csr_t_rfc_val              ),
        .csr_t_ref_min_val          (csr_t_ref_min_val          ),
        .csr_t_rp_val               (csr_t_rp_val               ),
        .csr_t_wrp_val              (csr_t_wrp_val              ),
        .csr_t_mrd_val              (csr_t_mrd_val              )
    );
endmodule
