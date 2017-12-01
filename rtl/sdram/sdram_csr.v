// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: sdram_csr.v
// Description: Sdram controller
// -----------------------------------------------------------------------------

module sdram_csr#(parameter AW = 16)
(
    input                 clk           ,
    input                 reset         ,
                          
    input  [AW-1:0]       wbs_address   ,
    input  [31:0]         wbs_writedata ,
    output reg [31:0]     wbs_readdata  ,
    input                 wbs_strobe    ,
    input                 wbs_cycle     ,
    input                 wbs_write     ,
    output reg            wbs_ack       ,

    // CSR
    output [0:0] csr_ctrl_start,
    output [0:0] csr_ctrl_self_refresh,
    output [1:0] csr_opmode_ba_reserved,
    output [2:0] csr_opmode_a_reserved,
    output [0:0] csr_opmode_wr_burst_mode,
    output [1:0] csr_opmode_operation_mode,
    output [2:0] csr_opmode_cas_latency,
    output [0:0] csr_opmode_burst_type,
    output [2:0] csr_opmode_burst_len,

    output [0:0] csr_config_prechg_after_rd,

    output [19:0] csr_t_dly_rst_val,
    output [ 7:0] csr_t_ac_val,
    output [ 7:0] csr_t_ah_val,
    output [ 7:0] csr_t_as_val,
    output [ 7:0] csr_t_ch_val,
    output [ 7:0] csr_t_cl_val,
    output [ 7:0] csr_t_ck_val,
    output [ 7:0] csr_t_ckh_val,
    output [ 7:0] csr_t_cks_val,
    output [ 7:0] csr_t_cmh_val,
    output [ 7:0] csr_t_cms_val,
    output [ 7:0] csr_t_dh_val,
    output [ 7:0] csr_t_ds_val,
    output [ 7:0] csr_t_hz_val,
    output [ 7:0] csr_t_lz_val,
    output [ 7:0] csr_t_oh_val,
    output [ 7:0] csr_t_ohn_val,
    output [ 7:0] csr_t_rasmin_val,
    output [19:0] csr_t_rasmax_val,
    output [ 7:0] csr_t_rc_val,
    output [ 7:0] csr_t_rcd_val,
    output [19:0] csr_t_ref_val,
    output [ 7:0] csr_t_rfc_val,
    output [ 9:0] csr_t_ref_min_val,
    output [ 7:0] csr_t_rp_val,
    output [ 7:0] csr_t_rrd_val,
    output [ 7:0] csr_t_wrap_val,
    output [ 7:0] csr_t_wrp_val,
    output [ 7:0] csr_t_xsr_val,
                           
    output [ 3:0] csr_r_t_bdl_val,
    output [ 3:0] csr_t_ccd_val,
    output [ 3:0] csr_t_cdl_val,
    output [ 3:0] csr_t_cked_val,
    output [ 3:0] csr_t_dal_val,
    output [ 3:0] csr_t_dpl_val,
    output [ 3:0] csr_t_dqd_val,
    output [ 3:0] csr_t_dqm_val,
    output [ 3:0] csr_t_dqz_val,
    output [ 3:0] csr_t_dwd_val,
    output [ 3:0] csr_t_mrd_val,
    output [ 3:0] csr_t_ped_val,
    output [ 3:0] csr_t_rdl_val,
    output [ 3:0] csr_t_roh_val
);

    // Wishbone
    wire wb_trans = wbs_strobe & wbs_cycle;
    reg  wb_trans_dly;
    wire wb_read  = wb_trans & ~wb_trans_dly & ~wbs_write;
    wire wb_write = wb_trans & ~wb_trans_dly & wbs_write;

    always @(posedge clk or posedge reset) begin
        if (reset) begin 
            wbs_ack      <= 1'h0;
            wb_trans_dly <= 1'h0;
        end else begin
            wbs_ack      <= wb_write | wb_read;
            wb_trans_dly <= wb_trans;
        end
    end

    // CSR
    reg [31:0] csr_ctrl;
    reg [31:0] csr_opmode;
    reg [31:0] csr_config;
    reg [31:0] csr_t_dly_rst;
    reg [31:0] csr_cl;
    reg [31:0] csr_t_ac;
    reg [31:0] csr_t_ah;
    reg [31:0] csr_t_as;
    reg [31:0] csr_t_ch;
    reg [31:0] csr_t_cl;
    reg [31:0] csr_t_ck;
    reg [31:0] csr_t_ckh;
    reg [31:0] csr_t_cks;
    reg [31:0] csr_t_cmh;
    reg [31:0] csr_t_cms;
    reg [31:0] csr_t_dh;
    reg [31:0] csr_t_ds;
    reg [31:0] csr_t_hz;
    reg [31:0] csr_t_lz;
    reg [31:0] csr_t_oh;
    reg [31:0] csr_t_ohn;
    reg [31:0] csr_t_rasmin;
    reg [31:0] csr_t_rasmax;
    reg [31:0] csr_t_rc;
    reg [31:0] csr_t_rcd;
    reg [31:0] csr_t_ref;
    reg [31:0] csr_t_rfc;
    reg [31:0] csr_t_ref_min;
    reg [31:0] csr_t_rp;
    reg [31:0] csr_t_rrd;
    reg [31:0] csr_t_wrap;
    reg [31:0] csr_t_wrp;
    reg [31:0] csr_t_xsr;

    reg [31:0] csr_t_bdl;
    reg [31:0] csr_t_ccd;
    reg [31:0] csr_t_cdl;
    reg [31:0] csr_t_cked;
    reg [31:0] csr_t_dal;
    reg [31:0] csr_t_dpl;
    reg [31:0] csr_t_dqd;
    reg [31:0] csr_t_dqm;
    reg [31:0] csr_t_dqz;
    reg [31:0] csr_t_dwd;
    reg [31:0] csr_t_mrd;
    reg [31:0] csr_t_ped;
    reg [31:0] csr_t_rdl;
    reg [31:0] csr_t_roh;

    assign { csr_ctrl_self_refresh     [0:0]    ,
             csr_ctrl_start            [0:0]    } = csr_ctrl;
    assign { csr_opmode_ba_reserved    [1:0]    ,
             csr_opmode_a_reserved     [2:0]    ,
             csr_opmode_wr_burst_mode  [0:0]    ,
             csr_opmode_operation_mode [1:0]    ,
             csr_opmode_cas_latency    [2:0]    ,
             csr_opmode_burst_type     [0:0]    ,
             csr_opmode_burst_len      [2:0]    } = csr_opmode;
    assign { csr_config_prechg_after_rd[0:0]    } = csr_config;


    assign { csr_t_dly_rst_val[19:0] } = csr_t_dly_rst[19:0];
    assign { csr_t_ac_val     [ 7:0] } = csr_t_ac     [ 7:0];
    assign { csr_t_ah_val     [ 7:0] } = csr_t_ah     [ 7:0];
    assign { csr_t_as_val     [ 7:0] } = csr_t_as     [ 7:0];
    assign { csr_t_ch_val     [ 7:0] } = csr_t_ch     [ 7:0];
    assign { csr_t_cl_val     [ 7:0] } = csr_t_cl     [ 7:0];
    assign { csr_t_ck_val     [ 7:0] } = csr_t_ck     [ 7:0];
    assign { csr_t_ckh_val    [ 7:0] } = csr_t_ckh    [ 7:0];
    assign { csr_t_cks_val    [ 7:0] } = csr_t_cks    [ 7:0];
    assign { csr_t_cmh_val    [ 7:0] } = csr_t_cmh    [ 7:0];
    assign { csr_t_cms_val    [ 7:0] } = csr_t_cms    [ 7:0];
    assign { csr_t_dh_val     [ 7:0] } = csr_t_dh     [ 7:0];
    assign { csr_t_ds_val     [ 7:0] } = csr_t_ds     [ 7:0];
    assign { csr_t_hz_val     [ 7:0] } = csr_t_hz     [ 7:0];
    assign { csr_t_lz_val     [ 7:0] } = csr_t_lz     [ 7:0];
    assign { csr_t_oh_val     [ 7:0] } = csr_t_oh     [ 7:0];
    assign { csr_t_ohn_val    [ 7:0] } = csr_t_ohn    [ 7:0];
    assign { csr_t_rasmin_val [ 7:0] } = csr_t_rasmin [ 7:0];
    assign { csr_t_rasmax_val [19:0] } = csr_t_rasmax [19:0];
    assign { csr_t_rc_val     [ 7:0] } = csr_t_rc     [ 7:0];
    assign { csr_t_rcd_val    [ 7:0] } = csr_t_rcd    [ 7:0];
    assign { csr_t_ref_val    [19:0] } = csr_t_ref    [19:0];
    assign { csr_t_rfc_val    [ 7:0] } = csr_t_rfc    [ 7:0];
    assign { csr_t_ref_min_val[ 9:0] } = csr_t_ref_min[ 9:0];
    assign { csr_t_rp_val     [ 7:0] } = csr_t_rp     [ 7:0];
    assign { csr_t_rrd_val    [ 7:0] } = csr_t_rrd    [ 7:0];
    assign { csr_t_wrap_val   [ 7:0] } = csr_t_wrap   [ 7:0];
    assign { csr_t_wrp_val    [ 7:0] } = csr_t_wrp    [ 7:0];
    assign { csr_t_xsr_val    [ 7:0] } = csr_t_xsr    [ 7:0];

    assign { csr_r_t_bdl_val  [ 3:0] } = csr_t_bdl    [ 3:0];
    assign { csr_t_ccd_val    [ 3:0] } = csr_t_ccd    [ 3:0];
    assign { csr_t_cdl_val    [ 3:0] } = csr_t_cdl    [ 3:0];
    assign { csr_t_cked_val   [ 3:0] } = csr_t_cked   [ 3:0];
    assign { csr_t_dal_val    [ 3:0] } = csr_t_dal    [ 3:0];
    assign { csr_t_dpl_val    [ 3:0] } = csr_t_dpl    [ 3:0];
    assign { csr_t_dqd_val    [ 3:0] } = csr_t_dqd    [ 3:0];
    assign { csr_t_dqm_val    [ 3:0] } = csr_t_dqm    [ 3:0];
    assign { csr_t_dqz_val    [ 3:0] } = csr_t_dqz    [ 3:0];
    assign { csr_t_dwd_val    [ 3:0] } = csr_t_dwd    [ 3:0];
    assign { csr_t_mrd_val    [ 3:0] } = csr_t_mrd    [ 3:0];
    assign { csr_t_ped_val    [ 3:0] } = csr_t_ped    [ 3:0];
    assign { csr_t_rdl_val    [ 3:0] } = csr_t_rdl    [ 3:0];
    assign { csr_t_roh_val    [ 3:0] } = csr_t_roh    [ 3:0];

    always @(posedge clk or posedge reset) begin
        if (reset) begin 
            csr_ctrl      <= 32'h0;
            csr_opmode    <= 32'h0;
            csr_config    <= 32'h0;

            csr_t_dly_rst <= T_DLY_RST;
            csr_t_ac      <= T_AC;
            csr_t_ah      <= T_AH;
            csr_t_as      <= T_AS;
            csr_t_ch      <= T_CH;
            csr_t_cl      <= T_CL;
            csr_t_ck      <= T_CK;
            csr_t_ckh     <= T_CKH;
            csr_t_cks     <= T_CKS;
            csr_t_cmh     <= T_CMH;
            csr_t_cms     <= T_CMS;
            csr_t_dh      <= T_DH;
            csr_t_ds      <= T_DS;
            csr_t_hz      <= T_HZ;
            csr_t_lz      <= T_LZ;
            csr_t_oh      <= T_OH;
            csr_t_ohn     <= T_OHN;
            csr_t_rasmin  <= T_RASMIN;
            csr_t_rasmax  <= T_RASMAX;
            csr_t_rc      <= T_RC;
            csr_t_rcd     <= T_RCD;
            csr_t_ref     <= T_REF;
            csr_t_rfc     <= T_RFC;
            csr_t_ref_min <= T_REF_MIN;
            csr_t_rp      <= T_RP;
            csr_t_rrd     <= T_RRD;
            csr_t_wrap    <= T_WRAP;
            csr_t_wrp     <= T_WRP;
            csr_t_xsr     <= T_XSR;
                         
            csr_t_bdl     <= T_BDL;
            csr_t_ccd     <= T_CCD;
            csr_t_cdl     <= T_CDL;
            csr_t_cked    <= T_CKED;
            csr_t_dal     <= T_DAL;
            csr_t_dpl     <= T_DPL;
            csr_t_dqd     <= T_DQD;
            csr_t_dqm     <= T_DQM;
            csr_t_dqz     <= T_DQZ;
            csr_t_dwd     <= T_DWD;
            csr_t_mrd     <= T_MRD;
            csr_t_ped     <= T_PED;
            csr_t_rdl     <= T_RDL;
            csr_t_roh     <= T_ROH;
        end
        else if (wb_write) begin
            case (wbs_address[7:0])
                8'h00: csr_ctrl      <= wbs_writedata;
                8'h04: csr_opmode    <= wbs_writedata;
                8'h08: csr_config    <= wbs_writedata;
                8'h20: csr_t_dly_rst <= wbs_writedata;
                8'h24: csr_t_ac      <= wbs_writedata;
                8'h28: csr_t_ah      <= wbs_writedata;
                8'h2c: csr_t_as      <= wbs_writedata;
                8'h30: csr_t_ch      <= wbs_writedata;
                8'h34: csr_t_cl      <= wbs_writedata;
                8'h38: csr_t_ck      <= wbs_writedata;
                8'h3c: csr_t_ckh     <= wbs_writedata;
                8'h40: csr_t_cks     <= wbs_writedata;
                8'h44: csr_t_cmh     <= wbs_writedata;
                8'h48: csr_t_cms     <= wbs_writedata;
                8'h4c: csr_t_dh      <= wbs_writedata;
                8'h50: csr_t_ds      <= wbs_writedata;
                8'h54: csr_t_hz      <= wbs_writedata;
                8'h58: csr_t_lz      <= wbs_writedata;
                8'h5c: csr_t_oh      <= wbs_writedata;
                8'h60: csr_t_ohn     <= wbs_writedata;
                8'h64: csr_t_rasmin  <= wbs_writedata;
                8'h68: csr_t_rasmax  <= wbs_writedata;
                8'h6c: csr_t_rc      <= wbs_writedata;
                8'h70: csr_t_rcd     <= wbs_writedata;
                8'h74: csr_t_ref     <= wbs_writedata;
                8'h78: csr_t_rfc     <= wbs_writedata;
                8'h7c: csr_t_ref_min <= wbs_writedata;
                8'h80: csr_t_rp      <= wbs_writedata;
                8'h84: csr_t_rrd     <= wbs_writedata;
                8'h88: csr_t_wrap    <= wbs_writedata;
                8'h8c: csr_t_wrp     <= wbs_writedata;
                8'h90: csr_t_xsr     <= wbs_writedata;
                8'h94: csr_t_bdl     <= wbs_writedata;
                8'h98: csr_t_ccd     <= wbs_writedata;
                8'h9c: csr_t_cdl     <= wbs_writedata;
                8'ha0: csr_t_cked    <= wbs_writedata;
                8'ha4: csr_t_dal     <= wbs_writedata;
                8'ha8: csr_t_dpl     <= wbs_writedata;
                8'hac: csr_t_dqd     <= wbs_writedata;
                8'hb0: csr_t_dqm     <= wbs_writedata;
                8'hb4: csr_t_dqz     <= wbs_writedata;
                8'hb8: csr_t_dwd     <= wbs_writedata;
                8'hbc: csr_t_mrd     <= wbs_writedata;
                8'hc0: csr_t_ped     <= wbs_writedata;
                8'hc4: csr_t_rdl     <= wbs_writedata;
                8'hc8: csr_t_roh     <= wbs_writedata;
            endcase
        end
    end

    always @(*) begin
        wbs_readdata = 32'h0;
        if (wb_read) begin
            case (wbs_address)
                'h00: wbs_readdata = csr_ctrl  ;
                'h04: wbs_readdata = csr_opmode;
                'h08: wbs_readdata = csr_config;

              //'h0c: wbs_readdata =           ; // Reserved
              //'h10: wbs_readdata =           ;
              //'h14: wbs_readdata =           ;
              //'h18: wbs_readdata =           ;
              //'h1c: wbs_readdata =           ;

                'h20: wbs_readdata = csr_t_dly_rst ;
                'h24: wbs_readdata = csr_t_ac      ;
                'h28: wbs_readdata = csr_t_ah      ;
                'h2c: wbs_readdata = csr_t_as      ;
                'h30: wbs_readdata = csr_t_ch      ;
                'h34: wbs_readdata = csr_t_cl      ;
                'h38: wbs_readdata = csr_t_ck      ;
                'h3c: wbs_readdata = csr_t_ckh     ;
                'h40: wbs_readdata = csr_t_cks     ;
                'h44: wbs_readdata = csr_t_cmh     ;
                'h48: wbs_readdata = csr_t_cms     ;
                'h4c: wbs_readdata = csr_t_dh      ;
                'h50: wbs_readdata = csr_t_ds      ;
                'h54: wbs_readdata = csr_t_hz      ;
                'h58: wbs_readdata = csr_t_lz      ;
                'h5c: wbs_readdata = csr_t_oh      ;
                'h60: wbs_readdata = csr_t_ohn     ;
                'h64: wbs_readdata = csr_t_rasmin  ;
                'h68: wbs_readdata = csr_t_rasmax  ;
                'h6c: wbs_readdata = csr_t_rc      ;
                'h70: wbs_readdata = csr_t_rcd     ;
                'h74: wbs_readdata = csr_t_ref     ;
                'h78: wbs_readdata = csr_t_rfc     ;
                'h7c: wbs_readdata = csr_t_ref_min ;
                'h80: wbs_readdata = csr_t_rp      ;
                'h84: wbs_readdata = csr_t_rrd     ;
                'h88: wbs_readdata = csr_t_wrap    ;
                'h8c: wbs_readdata = csr_t_wrp     ;
                'h90: wbs_readdata = csr_t_xsr     ;
                'h94: wbs_readdata = csr_t_bdl     ;
                'h98: wbs_readdata = csr_t_ccd     ;
                'h9c: wbs_readdata = csr_t_cdl     ;
                'ha0: wbs_readdata = csr_t_cked    ;
                'ha4: wbs_readdata = csr_t_dal     ;
                'ha8: wbs_readdata = csr_t_dpl     ;
                'hac: wbs_readdata = csr_t_dqd     ;
                'hb0: wbs_readdata = csr_t_dqm     ;
                'hb4: wbs_readdata = csr_t_dqz     ;
                'hb8: wbs_readdata = csr_t_dwd     ;
                'hbc: wbs_readdata = csr_t_mrd     ;
                'hc0: wbs_readdata = csr_t_ped     ;
                'hc4: wbs_readdata = csr_t_rdl     ;
                'hc8: wbs_readdata = csr_t_roh     ;
            endcase
        end
    end

    localparam TCLK  = 1000; // Clock period in ps


    function integer ceil_div;
        input integer val1;
        input integer val2;
        ceil_div = val1/val2 + ((val1 % val2 != 0) ? 1 : 0);
    endfunction


    function integer ns2ck_min;
        input integer value;
        begin
            //ns2ck_min = $ceil(value/TCLK);
            ns2ck_min = ceil_div(value, TCLK);
        end
    endfunction

    function integer ns2ck_max;
        input integer value;
        begin
            //ns2ck_max = $floor(value/TCLK);
            ns2ck_max = (value/TCLK);
        end
    endfunction

    function integer max;
        input integer val1;
        input integer val2;
        begin
            max = (val1 > val2) ? val1 : val2;
        end
    endfunction

    function integer ns2ck_min_bounded;
        input integer value;
        input integer min_val;
        begin
            //cl = $ceil(value/TCLK);
            ns2ck_min_bounded = max(ceil_div(value, TCLK), min_val);
        end
    endfunction

    localparam T_DLY_RST = ns2ck_min(100_000_000); // 100us delay prior issuing any command other than NOP or INHIBIT
    localparam T_AC      = ns2ck_max( 5400); // Access time from CLK (positive edge) CL = 2  
    localparam T_AH      = ns2ck_min(  800); // Address hold time
    localparam T_AS      = ns2ck_min( 1500); // Address setup time
    localparam T_CH      = ns2ck_min( 2500); // CLK high-level width
    localparam T_CL      = ns2ck_min( 2500); // CLK low-level width
    localparam T_CK      = ns2ck_min( 7500); // 7.5ns for CL=2 // Clock cycle time CL = 2
    localparam T_CKH     = ns2ck_min(  800); // CKE hold time
    localparam T_CKS     = ns2ck_min( 1500); // CKE setup time
    localparam T_CMH     = ns2ck_min(  800); // CS#, RAS#, CAS#, WE#, DQM hold time
    localparam T_CMS     = ns2ck_min( 1500); // CS#, RAS#, CAS#, WE#, DQM setup time
    localparam T_DH      = ns2ck_min(  800); // Data-in hold time
    localparam T_DS      = ns2ck_min( 1500); // Data-in setup time
    localparam T_HZ      = ns2ck_max( 5400); // Data-out High-Z time CL = 2
    localparam T_LZ      = ns2ck_min( 1000); // Data-out Low-Z time
    localparam T_OH      = ns2ck_min( 3000); // Data-out hold time (load)
    localparam T_OHN     = ns2ck_min( 1800); // Data-out hold time (no load)
    localparam T_RASMIN  = ns2ck_min(37000); // ACTIVE-to-PRECHARGE command
    localparam T_RASMAX  = ns2ck_max(120_000_000); // ACTIVE-to-PRECHARGE command
    localparam T_RC      = ns2ck_min( 60000); // ACTIVE-to-ACTIVE command period
    localparam T_RCD     = ns2ck_min( 15000); // ACTIVE-to-READ or WRITE delay
    localparam T_REF     = ns2ck_max( 64_000_000); // Refresh period (8192 rows)
    localparam T_RFC     = ns2ck_min( 66000); // AUTO REFRESH period
    localparam T_REF_MIN = ns2ck_min( 64_000_000/8192); // AUTO REFRESH min period
    localparam T_RP      = ns2ck_min( 15000); // PRECHARGE command period
    localparam T_RRD     = ns2ck_min( 14000); // ACTIVE bank a to ACTIVE bank b command
  //localparam T_T       = ns2ck_min_max( 300, 1200); // Transition time
    localparam T_WRAP    = ns2ck_min( 7000) + 1; // WRITE recovery time
    localparam T_WRP     = ns2ck_min( 14000); // WRITE recovery time
    localparam T_XSR     = ns2ck_min_bounded(67000, 2); // Exit SELF REFRESH-to-ACTIVE command 

    localparam T_BDL     = 1; // Last data-in to burst STOP command  
    localparam T_CCD     = 1; // READ/WRITE command to READ/WRITE command  
    localparam T_CDL     = 1; // Last data-in to new READ/WRITE command  
    localparam T_CKED    = 1; // CKE to clock disable or power-down entry 1
    localparam T_DAL     = 4; // Data-in to ACTIVE command  
    localparam T_DPL     = 2; // Data-in to PRECHARGE command  
    localparam T_DQD     = 0; // DQM to input data delay  
    localparam T_DQM     = 0; // DQM to data mask during WRITEs  
    localparam T_DQZ     = 2; // DQM to data High-Z during READs  
    localparam T_DWD     = 0; // WRITE command to input data delay  
    localparam T_MRD     = 2; // LOAD MODE REGISTER command to ACTIVE or REFRESH command  
    localparam T_PED     = 1; // CKE to clock enable or power-down exit setup mode  
    localparam T_RDL     = 2; // Last data-in to PRECHARGE command  
    localparam T_ROH     = 2; // Data-out High-Z from PRECHARGE command CL = 2  

endmodule
