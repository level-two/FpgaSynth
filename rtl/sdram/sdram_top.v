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
    //output                   wbs_sdram_err       , // TBI

    // INTERFACE TO SDRAM
    output                     sdram_clk           ,
    output                     sdram_cke           ,
    output                     sdram_ncs           ,
    output                     sdram_ncas          ,
    output                     sdram_nras          ,
    output                     sdram_nwe           ,
    output                     sdram_dqml          ,
    output                     sdram_dqmh          ,
    output [12:0]              sdram_a             ,
    output [ 1:0]              sdram_ba            ,
    input  [15:0]              sdram_dq
);

    parameter AW_CSR   = 16;

    wire [31:0]    sdram_addr;
    wire           sdram_wr;
    wire           sdram_rd;
    wire [15:0]    sdram_wr_data;
    wire [15:0]    sdram_rd_data;
    wire           sdram_op_done;
    //wire         sdram_op_err; // TBI
    //wire         sdram_busy;   // TBI

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
        //.wbs_err                  (wbs_sdram_err              ), // TBI
                                                                
        .sdram_addr                 (sdram_addr                 ),
        .sdram_wr                   (sdram_wr                   ),
        .sdram_rd                   (sdram_rd                   ),
        .sdram_wr_data              (sdram_wr_data              ),
        .sdram_rd_data              (sdram_rd_data              ),
        .sdram_op_done              (sdram_op_done              ) 
        //.sdram_op_err             (sdram_op_err               ), // TBI
    );

    wire[ 0:0] csr_ctrl_start;
    wire[ 0:0] csr_ctrl_self_refresh;
    wire[ 1:0] csr_opmode_ba_reserved;
    wire[ 2:0] csr_opmode_a_reserved;
    wire[ 0:0] csr_opmode_wr_burst_mode;
    wire[ 1:0] csr_opmode_operation_mode;
    wire[ 2:0] csr_opmode_cas_latency;
    wire[ 0:0] csr_opmode_burst_type;
    wire[ 2:0] csr_opmode_burst_len;
    wire[ 0:0] csr_config_prechg_after_rd;
    wire[19:0] csr_t_dly_rst_val;
    wire[ 7:0] csr_t_ac_val;
    wire[ 7:0] csr_t_ah_val;
    wire[ 7:0] csr_t_as_val;
    wire[ 7:0] csr_t_ch_val;
    wire[ 7:0] csr_t_cl_val;
    wire[ 7:0] csr_t_ck_val;
    wire[ 7:0] csr_t_ckh_val;
    wire[ 7:0] csr_t_cks_val;
    wire[ 7:0] csr_t_cmh_val;
    wire[ 7:0] csr_t_cms_val;
    wire[ 7:0] csr_t_dh_val;
    wire[ 7:0] csr_t_ds_val;
    wire[ 7:0] csr_t_hz_val;
    wire[ 7:0] csr_t_lz_val;
    wire[ 7:0] csr_t_oh_val;
    wire[ 7:0] csr_t_ohn_val;
    wire[ 7:0] csr_t_rasmin_val;
    wire[19:0] csr_t_rasmax_val;
    wire[ 7:0] csr_t_rc_val;
    wire[ 7:0] csr_t_rcd_val;
    wire[19:0] csr_t_ref_val;
    wire[ 7:0] csr_t_rfc_val;
    wire[ 9:0] csr_t_ref_min_val;
    wire[ 7:0] csr_t_rp_val;
    wire[ 7:0] csr_t_rrd_val;
    wire[ 7:0] csr_t_wrp_val;
    wire[ 7:0] csr_t_xsr_val;
    wire[ 3:0] csr_r_t_bdl_val;
    wire[ 3:0] csr_t_ccd_val;
    wire[ 3:0] csr_t_cdl_val;
    wire[ 3:0] csr_t_cked_val;
    wire[ 3:0] csr_t_dal_val;
    wire[ 3:0] csr_t_dpl_val;
    wire[ 3:0] csr_t_dqd_val;
    wire[ 3:0] csr_t_dqm_val;
    wire[ 3:0] csr_t_dqz_val;
    wire[ 3:0] csr_t_dwd_val;
    wire[ 3:0] csr_t_mrd_val;
    wire[ 3:0] csr_t_ped_val;
    wire[ 3:0] csr_t_rdl_val;
    wire[ 3:0] csr_t_roh_val;

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
        .csr_opmode_ba_reserved     (csr_opmode_ba_reserved     ),
        .csr_opmode_a_reserved      (csr_opmode_a_reserved      ),
        .csr_opmode_wr_burst_mode   (csr_opmode_wr_burst_mode   ),
        .csr_opmode_operation_mode  (csr_opmode_operation_mode  ),
        .csr_opmode_cas_latency     (csr_opmode_cas_latency     ),
        .csr_opmode_burst_type      (csr_opmode_burst_type      ),
        .csr_opmode_burst_len       (csr_opmode_burst_len       ),
        .csr_config_prechg_after_rd (csr_config_prechg_after_rd ),
        .csr_t_dly_rst_val          (csr_t_dly_rst_val          ),
        .csr_t_ac_val               (csr_t_ac_val               ),
        .csr_t_ah_val               (csr_t_ah_val               ),
        .csr_t_as_val               (csr_t_as_val               ),
        .csr_t_ch_val               (csr_t_ch_val               ),
        .csr_t_cl_val               (csr_t_cl_val               ),
        .csr_t_ck_val               (csr_t_ck_val               ),
        .csr_t_ckh_val              (csr_t_ckh_val              ),
        .csr_t_cks_val              (csr_t_cks_val              ),
        .csr_t_cmh_val              (csr_t_cmh_val              ),
        .csr_t_cms_val              (csr_t_cms_val              ),
        .csr_t_dh_val               (csr_t_dh_val               ),
        .csr_t_ds_val               (csr_t_ds_val               ),
        .csr_t_hz_val               (csr_t_hz_val               ),
        .csr_t_lz_val               (csr_t_lz_val               ),
        .csr_t_oh_val               (csr_t_oh_val               ),
        .csr_t_ohn_val              (csr_t_ohn_val              ),
        .csr_t_rasmin_val           (csr_t_rasmin_val           ),
        .csr_t_rasmax_val           (csr_t_rasmax_val           ),
        .csr_t_rc_val               (csr_t_rc_val               ),
        .csr_t_rcd_val              (csr_t_rcd_val              ),
        .csr_t_ref_val              (csr_t_ref_val              ),
        .csr_t_rfc_val              (csr_t_rfc_val              ),
        .csr_t_ref_min_val          (csr_t_ref_min_val          ),
        .csr_t_rp_val               (csr_t_rp_val               ),
        .csr_t_rrd_val              (csr_t_rrd_val              ),
        .csr_t_wrp_val              (csr_t_wrp_val              ),
        .csr_t_xsr_val              (csr_t_xsr_val              ),
        .csr_r_t_bdl_val            (csr_r_t_bdl_val            ),
        .csr_t_ccd_val              (csr_t_ccd_val              ),
        .csr_t_cdl_val              (csr_t_cdl_val              ),
        .csr_t_cked_val             (csr_t_cked_val             ),
        .csr_t_dal_val              (csr_t_dal_val              ),
        .csr_t_dpl_val              (csr_t_dpl_val              ),
        .csr_t_dqd_val              (csr_t_dqd_val              ),
        .csr_t_dqm_val              (csr_t_dqm_val              ),
        .csr_t_dqz_val              (csr_t_dqz_val              ),
        .csr_t_dwd_val              (csr_t_dwd_val              ),
        .csr_t_mrd_val              (csr_t_mrd_val              ),
        .csr_t_ped_val              (csr_t_ped_val              ),
        .csr_t_rdl_val              (csr_t_rdl_val              ),
        .csr_t_roh_val              (csr_t_roh_val              )
    );

    sdram_ctrl sdram_ctrl_inst (
        .clk                        (clk                        ),
        .reset                      (reset                      ),
                                                                
        .sdram_addr                 (sdram_addr                 ),
        .sdram_wr                   (sdram_wr                   ),
        .sdram_rd                   (sdram_rd                   ),
        .sdram_wr_data              (sdram_wr_data              ),
        .sdram_rd_data              (sdram_rd_data              ),
        .sdram_op_done              (sdram_op_done              ),
        //.sdram_op_err             (sdram_op_err               ), // TBI
        //.sdram_busy               (sdram_busy                 ), // TBI
                                                                
        .sdram_clk                  (sdram_clk                  ),
        .sdram_cke                  (sdram_cke                  ),
        .sdram_ncs                  (sdram_ncs                  ),
        .sdram_ncas                 (sdram_ncas                 ),
        .sdram_nras                 (sdram_nras                 ),
        .sdram_nwe                  (sdram_nwe                  ),
        .sdram_dqml                 (sdram_dqml                 ),
        .sdram_dqmh                 (sdram_dqmh                 ),
        .sdram_a                    (sdram_a                    ),
        .sdram_ba                   (sdram_ba                   ),
        .sdram_dq                   (sdram_dq                   ),

        // CSR
        .csr_ctrl_start             (csr_ctrl_start             ),
        .csr_ctrl_self_refresh      (csr_ctrl_self_refresh      ),
        .csr_opmode_ba_reserved     (csr_opmode_ba_reserved     ),
        .csr_opmode_a_reserved      (csr_opmode_a_reserved      ),
        .csr_opmode_wr_burst_mode   (csr_opmode_wr_burst_mode   ),
        .csr_opmode_operation_mode  (csr_opmode_operation_mode  ),
        .csr_opmode_cas_latency     (csr_opmode_cas_latency     ),
        .csr_opmode_burst_type      (csr_opmode_burst_type      ),
        .csr_opmode_burst_len       (csr_opmode_burst_len       ),
        .csr_config_prechg_after_rd (csr_config_prechg_after_rd ),
        .csr_t_dly_rst_val          (csr_t_dly_rst_val          ),
        .csr_t_ac_val               (csr_t_ac_val               ),
        .csr_t_ah_val               (csr_t_ah_val               ),
        .csr_t_as_val               (csr_t_as_val               ),
        .csr_t_ch_val               (csr_t_ch_val               ),
        .csr_t_cl_val               (csr_t_cl_val               ),
        .csr_t_ck_val               (csr_t_ck_val               ),
        .csr_t_ckh_val              (csr_t_ckh_val              ),
        .csr_t_cks_val              (csr_t_cks_val              ),
        .csr_t_cmh_val              (csr_t_cmh_val              ),
        .csr_t_cms_val              (csr_t_cms_val              ),
        .csr_t_dh_val               (csr_t_dh_val               ),
        .csr_t_ds_val               (csr_t_ds_val               ),
        .csr_t_hz_val               (csr_t_hz_val               ),
        .csr_t_lz_val               (csr_t_lz_val               ),
        .csr_t_oh_val               (csr_t_oh_val               ),
        .csr_t_ohn_val              (csr_t_ohn_val              ),
        .csr_t_rasmin_val           (csr_t_rasmin_val           ),
        .csr_t_rasmax_val           (csr_t_rasmax_val           ),
        .csr_t_rc_val               (csr_t_rc_val               ),
        .csr_t_rcd_val              (csr_t_rcd_val              ),
        .csr_t_ref_val              (csr_t_ref_val              ),
        .csr_t_rfc_val              (csr_t_rfc_val              ),
        .csr_t_ref_min_val          (csr_t_ref_min_val          ),
        .csr_t_rp_val               (csr_t_rp_val               ),
        .csr_t_rrd_val              (csr_t_rrd_val              ),
        .csr_t_wrp_val              (csr_t_wrp_val              ),
        .csr_t_xsr_val              (csr_t_xsr_val              ),
        .csr_r_t_bdl_val            (csr_r_t_bdl_val            ),
        .csr_t_ccd_val              (csr_t_ccd_val              ),
        .csr_t_cdl_val              (csr_t_cdl_val              ),
        .csr_t_cked_val             (csr_t_cked_val             ),
        .csr_t_dal_val              (csr_t_dal_val              ),
        .csr_t_dpl_val              (csr_t_dpl_val              ),
        .csr_t_dqd_val              (csr_t_dqd_val              ),
        .csr_t_dqm_val              (csr_t_dqm_val              ),
        .csr_t_dqz_val              (csr_t_dqz_val              ),
        .csr_t_dwd_val              (csr_t_dwd_val              ),
        .csr_t_mrd_val              (csr_t_mrd_val              ),
        .csr_t_ped_val              (csr_t_ped_val              ),
        .csr_t_rdl_val              (csr_t_rdl_val              ),
        .csr_t_roh_val              (csr_t_roh_val              )
    );
endmodule
