// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: module_lpf.v.v
// Description: LPF implementation based on IIR scheme and Xilinx DSP48A1
// -----------------------------------------------------------------------------

`include "globals.vh"

module module_lpf.v (
    input                       clk,
    input                       reset,

    input                       midi_rdy,
    input  [`MIDI_CMD_SIZE-1:0] midi_cmd,
    input  [3:0]                midi_ch_sysn,
    input  [6:0]                midi_data0,
    input  [6:0]                midi_data1,

    input                       sample_in_rdy,
    input signed [17:0]         sample_in,

    output reg                  sample_out_rdy,
    output reg signed [17:0]    sample_out
);

//--------------------------------------------------------
// -------====== State Machine ======-------
//-----------------------------------------------------
    localparam ST_IDLE           = 0;
    localparam ST_STORE_SAMPLE   = 1;
    localparam ST_CALC_A         = 2;
    localparam ST_WAIT_RESULT_A  = 3;
    localparam ST_STORE_RESULT_A = 4;
    localparam ST_CALC_B         = 5;
    localparam ST_WAIT_RESULT_B  = 6;
    localparam ST_DONE           = 7;

    reg [2:0] state;
    reg [2:0] next_state;

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            state <= ST_IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            ST_IDLE:
                if (sample_in_rdy) begin
                    next_state = ST_CALC_A;
                end
            ST_STORE_SAMPLE:
                if (calc_coef_cnt_done) begin
                    next_state = ST_CALC_B;
                end
            ST_CALC_A:
                if (calc_coef_cnt_done) begin
                    next_state = ST_CALC_B;
                end
            ST_WAIT_RESULT_A:
                if (calc_coef_cnt_done) begin
                    next_state = ST_CALC_B;
                end
            ST_STORE_RESULT_A:
                if (calc_coef_cnt_done) begin
                    next_state = ST_CALC_B;
                end
            ST_CALC_B:
                if (calc_coef_cnt_done) begin
                    next_state = ST_WAIT_CALC_DONE;
                end
            ST_WAIT_RESULT_B:
                if (calc_coef_cnt_done) begin
                    next_state = ST_CALC_B;
                end
            ST_DONE:
                next_state = ST_IDLE;
        endcase
    end


//------------------------------------
// -------====== COEFS ======-------
//--------------------------------
    // Counter control
    reg [1:0] coef_sel;
    wire      coef_sel_last  = (coef_sel == 2'h2);
    reg signed [17:0] a_coef;
    reg signed [17:0] b_coef;
    

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            coef_sel <= 0;
        end
        else if (state == ST_CALC_A || state == ST_CALC_B) begin
            coef_sel <= coef_sel + 1;
        end
        else begin
            coef_sel <= 0;
        end
    end

    // A Coefs
    always (@coef_sel) begin
        case (coef_sel)
            2'h0:    begin a_coef <= 18'h10000; end // should always be 1.0
            2'h1:    begin a_coef <= 18'h00000; end
            2'h2:    begin a_coef <= 18'h00000; end
            default: begin a_coef <= 18'h00000; end
        endcase
    end

    // B Coefs
    always (@coef_sel) begin
        case (coef_sel)
            2'h0:    begin b_coef <= 18'h00000; end
            2'h1:    begin b_coef <= 18'h00000; end
            2'h2:    begin b_coef <= 18'h00000; end
            default: begin b_coef <= 18'h00000; end
        endcase
    end


//---------------------------------------------
// -------====== Delay line ======-------
//-----------------------------------------
    reg signed [17:0] sample_in_dly;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            sample_in_dly <= 18'h00000;
        end
        else begin
            sample_in_dly <= sample_in;
        end
    end


    reg  signed [17:0] smpl_dly_line[0:2];
    wire signed [17:0] smpl_delayed = smpl_dly_line[coef_sel];

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            smpl_dly_line[0] <= 18'h00000;
            smpl_dly_line[1] <= 18'h00000;
            smpl_dly_line[2] <= 18'h00000;
        end
        else if (state == ST_STORE_RESULT_A) begin
            smpl_dly_line[0] <= p;
        end
        else if (state == ST_STORE_SAMPLE) begin
            smpl_dly_line[0] <= sample_in_dly;
            smpl_dly_line[1] <= smpl_dly_line[0];
            smpl_dly_line[2] <= smpl_dly_line[1];
        end
    end


//----------------------------------
// -------====== A,B ======-------
//------------------------------
    assign a = smpl_delayed;
    assign b = (state == ST_CALC_A) ? a_coef :
               (state == ST_CALC_B) ? b_coef :
               18'h00000;


//-------------------------------------------------------------
// -------====== ALU Operation mode controll ======-------
//---------------------------------------------------------
    always @(state) begin
        opmode_x_in        = OP_X_IN_ZERO;
        opmode_z_in        = OP_Z_IN_ZERO;
        opmode_use_preadd  = 1'b0;
        opmode_cryin       = 1'b0;
        opmode_preadd_sub  = 1'b0;
        opmode_postadd_sub = 1'b0;

        case (state)
            ST_IDLE:           begin end
            ST_STORE_SAMPLE:   begin end
            ST_CALC_A: begin
                opmode_x_in = OP_X_IN_MULT;
                opmode_z_in = OP_Z_IN_POUT;
            end
            ST_WAIT_RESULT_A:  begin end
            ST_STORE_RESULT_A: begin end
            ST_CALC_B:         begin end
            ST_WAIT_RESULT_B:  begin end
            ST_DONE:           begin end
        endcase
    end








//---------------------------------------------
// -------====== Controll ======-------
//-----------------------------------------

    wire [1:0]  opmode_x_in;
    wire [1:0]  opmode_z_in;
    wire        opmode_use_preadd;
    wire        opmode_cryin;
    wire        opmode_preadd_sub;
    wire        opmode_postadd_sub;

    wire [7:0]  opmode_in = {opmode_postadd_sub, opmode_preadd_sub,
                             opmode_cryin      , opmode_use_preadd,
                             opmode_z_in       , opmode_x_in      };

    reg [7:0] opmode_in_dly[0:1];
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            opmode_in_dly[0] <= 8'h00;
            opmode_in_dly[1] <= 8'h00;
        end
        else begin
            opmode_in_dly[0] <= opmode_in;
            opmode_in_dly[1] <= opmode_in_dly[0];
        end
    end

    wire        opmode_postadd_sub_dly = opmode_in_dly[1][7];
    wire        opmode_preadd_sub_dly  = opmode_in[6];
    wire        opmode_cryin_dly       = opmode_in_dly[1][5];
    wire        opmode_use_preadd_dly  = opmode_in[4];
    wire [1:0]  opmode_z_in_dly        = opmode_in_dly[1][3:2];
    wire [1:0]  opmode_x_in_dly        = opmode_in_dly[1][1:0];

    assign  opmode = {opmode_postadd_sub_dly, opmode_preadd_sub_dly,
                      opmode_cryin_dly      , opmode_use_preadd_dly ,
                      opmode_z_in_dly       , opmode_x_in_dly       };


//----------------------------------
// -------====== ALU ======-------
//------------------------------

    localparam OP_X_IN_ZERO = 2'b00;
    localparam OP_X_IN_MULT = 2'b01;
    localparam OP_X_IN_POUT = 2'b10;
    localparam OP_X_IN_DAB  = 2'b11;

    localparam OP_Z_IN_ZERO = 2'b00;
    localparam OP_Z_IN_PCIN = 2'b01;
    localparam OP_Z_IN_POUT = 2'b10;
    localparam OP_Z_IN_CIN  = 2'b11;

    wire [17:0] a;
    wire [17:0] b;
    wire [47:0] p;
    wire [7:0]  opmode;

    /*
    wire [1:0]  opmode_x_in;
    wire [1:0]  opmode_z_in;
    wire        opmode_use_preadd;
    wire        opmode_cryin = 1'b0;
    wire        opmode_preadd_sub;
    wire        opmode_postadd_sub;
    wire [7:0]  opmode = {opmode_postadd_sub, opmode_preadd_sub, opmode_cryin,
                          opmode_use_preadd , opmode_z_in      , opmode_x_in};
    */

    // not connected
    wire [35:0] m_nc;
    wire [17:0] bcout_nc;
    wire [47:0] pcout_nc;
    wire [47:0] pcin_nc;
    wire        carryin_nc;
    wire        carryout_nc;
    wire        carryoutf_nc;


    DSP48A1 #(
        .A0REG      (0          ),  // First stage A pipeline register (0/1)
        .A1REG      (1          ),  // Second stage A pipeline register (0/1)
        .B0REG      (0          ),  // First stage B pipeline register (0/1)
        .B1REG      (1          ),  // Second stage B pipeline register (0/1)
        .CARRYINREG (0          ),  // CARRYIN pipeline register (0/1)
        .CARRYINSEL ("OPMODE5"  ),  // Specify carry-in source, "CARRYIN" or "OPMODE5" 
        .CARRYOUTREG(0          ),  // CARRYOUT output pipeline register (0/1)
        .CREG       (0          ),  // C pipeline register (0/1)
        .DREG       (0          ),  // D pre-adder pipeline register (0/1)
        .MREG       (1          ),  // M pipeline register (0/1)
        .OPMODEREG  (1          ),  // Enable=1/disable=0 OPMODE pipeline registers
        .PREG       (1          ),  // P output pipeline register (0/1)
        .RSTTYPE    ("SYNC"     )   // Specify reset type, "SYNC" or "ASYNC" 
    )
    DSP48A1_inst (
        .BCOUT     (bcout_nc    ), // B port cascade output
        .PCOUT     (pcout_nc    ), // P cascade output (if used, connect to PCIN of another DSP48A1)
        .CARRYOUT  (carryout_nc ), // Carry output (if used, connect to CARRYIN pin of another DSP48A1)
        .CARRYOUTF (carryoutf_nc), // Fabric carry output
        .M         (m_nc        ), // Fabric multiplier data output
        .P         (p           ), // Data output
        .PCIN      (pcin_nc     ), // P cascade (if used, connect to PCOUT of another DSP48A1)
        .CLK       (clk         ), // Clock 
        .OPMODE    (opmode      ), // Operation mode 
        .A         (a           ), // A data 
        .B         (b           ), // B data (connected to fabric or BCOUT of adjacent DSP48A1)
        .C         (48'b0       ), // C data 
        .CARRYIN   (carryin_nc  ), // Carry signal (if used, connect to CARRYOUT pin of another DSP48A1)
        .D         (18'h00000   ), // B pre-adder data 
        .CEA       (1'b1        ), // Active high clock enable for A registers
        .CEB       (1'b1        ), // Active high clock enable for B registers
        .CEC       (1'b0        ), // Active high clock enable for C registers
        .CECARRYIN (1'b0        ), // Active high clock enable for CARRYIN registers
        .CED       (1'b0        ), // Active high clock enable for D registers
        .CEM       (1'b1        ), // Active high clock enable for multiplier registers
        .CEOPMODE  (1'b1        ), // Active high clock enable for OPMODE registers
        .CEP       (1'b1        ), // Active high clock enable for P registers
        .RSTA      (reset       ), // Reset for A pipeline registers
        .RSTB      (reset       ), // Reset for B pipeline registers
        .RSTC      (1'b0        ), // Reset for C pipeline registers
        .RSTCARRYIN(1'b0        ), // Reset for CARRYIN pipeline registers
        .RSTD      (1'b0        ), // Reset for D pipeline registers
        .RSTM      (reset       ), // Reset for M pipeline registers
        .RSTOPMODE (reset       ), // Reset for OPMODE pipeline registers
        .RSTP      (reset       )  // Reset for P pipeline registers
    );


//--------------------------------------------------------
// -------====== Output ======-------
//----------------------------------------------------
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            sample_out     <= 18'h00000;
            sample_out_rdy <= 0;
        end
        else if (state == ST_DONE) begin
            sample_out     <= p[17:0];
            sample_out_rdy <= 1;
        end
        else begin
            sample_out_rdy <= 0;
        end
    end


//-----------------------------------------------------------------
// -------====== MIDI Events processing ======-------
//-------------------------------------------------------------
    wire      cc_event = (midi_rdy && midi_cmd == `MIDI_CMD_CC);
    reg [7:0] cc_num;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            cc_num <= 0;
        end
        else if (note_on_event) begin
            cc_num <= midi_data0;
        end
    end
endmodule
