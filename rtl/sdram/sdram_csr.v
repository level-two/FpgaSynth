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
    output [0:0] csr_ctrl_load_mode_register ,
    output [1:0] csr_opmode_ba_reserved,
    output [2:0] csr_opmode_a_reserved,
    output [0:0] csr_opmode_wr_burst_mode,
    output [1:0] csr_opmode_operation_mode,
    output [2:0] csr_opmode_cas_latency,
    output [0:0] csr_opmode_burst_type,
    output [2:0] csr_opmode_burst_len,

    output [0:0] csr_config_prechg_after_rd,

    output [19:0] csr_t_dly_rst_val,
    output [ 7:0] csr_t_rcd_val,
    output [ 7:0] csr_t_rfc_val,
    output [ 9:0] csr_t_ref_min_val,
    output [ 7:0] csr_t_rp_val,
    output [ 1:0] csr_t_wrp_val,
    output [ 3:0] csr_t_mrd_val
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
    reg [31:0] csr_t_rcd;
    reg [31:0] csr_t_rfc;
    reg [31:0] csr_t_ref_min;
    reg [31:0] csr_t_rp;
    reg [31:0] csr_t_wrp;
    reg [31:0] csr_t_xsr;
    reg [31:0] csr_t_mrd;

    assign { csr_ctrl_load_mode_register[0:0]   ,
             csr_ctrl_self_refresh     [0:0]    ,
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
    assign { csr_t_rcd_val    [ 7:0] } = csr_t_rcd    [ 7:0];
    assign { csr_t_rfc_val    [ 7:0] } = csr_t_rfc    [ 7:0];
    assign { csr_t_ref_min_val[ 9:0] } = csr_t_ref_min[ 9:0];
    assign { csr_t_rp_val     [ 7:0] } = csr_t_rp     [ 7:0];
    assign { csr_t_wrp_val    [ 1:0] } = csr_t_wrp    [ 1:0];
    assign { csr_t_mrd_val    [ 3:0] } = csr_t_mrd    [ 3:0];

    always @(posedge clk or posedge reset) begin
        if (reset) begin 
            csr_ctrl      <= 32'h0;
            csr_opmode    <= {19'h0, 3'b000, 1'b1, 2'b00, 3'b011, 1'b0, 3'b0};
            csr_config    <= 32'h0;

            csr_t_dly_rst <= T_DLY_RST;
            csr_t_rcd     <= T_RCD;
            csr_t_rfc     <= T_RFC;
            csr_t_ref_min <= T_REF_MIN;
            csr_t_rp      <= T_RP;
            csr_t_wrp     <= T_WRP;
            csr_t_mrd     <= T_MRD;
        end
        else if (wb_write) begin
            case (wbs_address[7:0])
                8'h00: csr_ctrl      <= wbs_writedata;
                8'h04: csr_opmode    <= wbs_writedata;
                8'h08: csr_config    <= wbs_writedata;
                8'h0c: csr_t_dly_rst <= wbs_writedata;
                8'h10: csr_t_rcd     <= wbs_writedata;
                8'h14: csr_t_rfc     <= wbs_writedata;
                8'h18: csr_t_ref_min <= wbs_writedata;
                8'h1c: csr_t_rp      <= wbs_writedata;
                8'h20: csr_t_wrp     <= wbs_writedata;
                8'h24: csr_t_mrd     <= wbs_writedata;
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
                'h0c: wbs_readdata = csr_t_dly_rst ;
                'h10: wbs_readdata = csr_t_rcd     ;
                'h14: wbs_readdata = csr_t_rfc     ;
                'h18: wbs_readdata = csr_t_ref_min ;
                'h1c: wbs_readdata = csr_t_rp      ;
                'h20: wbs_readdata = csr_t_wrp     ;
                'h24: wbs_readdata = csr_t_mrd     ;
            endcase
        end
    end

    localparam TCLK  = 10000; // Clock period in ps


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
    localparam T_RFC     = ns2ck_min( 66000); // AUTO REFRESH period
    localparam T_REF_MIN = ns2ck_min( 7_813_000); // AUTO REFRESH min period
    localparam T_RP      = ns2ck_min( 15000); // PRECHARGE command period
    localparam T_RRD     = ns2ck_min( 14000); // ACTIVE bank a to ACTIVE bank b command
  //localparam T_T       = ns2ck_min_max( 300, 1200); // Transition time
    //localparam T_WRAP    = ns2ck_min( 7000) + 1; // WRITE recovery time
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
