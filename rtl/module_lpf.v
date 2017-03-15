// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: module_lpf.v
// Description: LPF implementation based on IIR scheme and Xilinx DSP48A1
// -----------------------------------------------------------------------------

`include "globals.vh"

module module_lpf (
    input                       clk,
    input                       reset,

    input                       midi_rdy,
    input  [`MIDI_CMD_SIZE-1:0] midi_cmd,
    input  [3:0]                midi_ch_sysn,
    input  [6:0]                midi_data0,
    input  [6:0]                midi_data1,

    input                       sample_in_rdy,
    input signed [17:0]         sample_in,

    output                      sample_out_rdy,
    output signed [17:0]        sample_out
);

//--------------------------------------------------------
// -------====== State Machine ======-------
//-----------------------------------------------------
    localparam ST_IDLE           = 0;
    localparam ST_CALC_A         = 1;
    localparam ST_WAIT_RESULT_A  = 2;
    localparam ST_STORE_RESULT_A = 3;
    localparam ST_CALC_B         = 4;
    localparam ST_WAIT_RESULT_B  = 5;
    localparam ST_DONE           = 6;

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
            ST_CALC_A:
                if (coef_sel_last) begin
                    next_state = ST_WAIT_RESULT_A;
                end
            ST_WAIT_RESULT_A:
                if (calc_will_be_done) begin
                    next_state = ST_STORE_RESULT_A;
                end
            ST_STORE_RESULT_A:
                next_state = ST_CALC_B;
            ST_CALC_B:
                if (coef_sel_last) begin
                    next_state = ST_WAIT_RESULT_B;
                end
            ST_WAIT_RESULT_B:
                if (calc_will_be_done) begin
                    next_state = ST_DONE;
                end
            ST_DONE:
                next_state = ST_IDLE;
        endcase
    end


//------------------------------------
// -------====== ALU SIGNALS ======-------
//--------------------------------
    wire signed [17:0] a;
    wire signed [17:0] b;
    wire signed [47:0] p;
    wire        [7:0]  opmode;


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
        else if ((state == ST_CALC_A  || 
                  state == ST_CALC_B) &&
                 !coef_sel_last)
        begin
            coef_sel <= coef_sel + 1;
        end
        else begin
            coef_sel <= 0;
        end
    end

    // A Coefs
    always @(coef_sel) begin
        case (coef_sel)
            2'h0:    begin a_coef <= 18'h10000; end // should always be 1.0
            2'h1:    begin a_coef <= 18'h3f000; end
            2'h2:    begin a_coef <= 18'h01000; end
            default: begin a_coef <= 18'h00000; end
        endcase
    end

    // B Coefs
    always @(coef_sel) begin
        case (coef_sel)
            2'h0:    begin b_coef <= 18'h01000; end
            2'h1:    begin b_coef <= 18'h3f000; end
            2'h2:    begin b_coef <= 18'h01000; end
            default: begin b_coef <= 18'h00000; end
        endcase
    end


//---------------------------------------------
// -------====== Delay line ======-------
//-----------------------------------------
    reg  signed [17:0] smpl_dly_line[0:2];
    wire signed [17:0] smpl_delayed = smpl_dly_line[coef_sel];

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            smpl_dly_line[0] <= 18'h00000;
            smpl_dly_line[1] <= 18'h00000;
            smpl_dly_line[2] <= 18'h00000;
        end
        else if (state == ST_IDLE && sample_in_rdy) begin
            smpl_dly_line[0] <= sample_in;
            smpl_dly_line[1] <= smpl_dly_line[0];
            smpl_dly_line[2] <= smpl_dly_line[1];
        end
        else if (state == ST_STORE_RESULT_A) begin
            smpl_dly_line[0] <= p[33:16];
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
            ST_CALC_A: begin
                opmode_x_in = OP_X_IN_MULT;
                opmode_z_in = OP_Z_IN_POUT;
            end
            ST_WAIT_RESULT_A:  begin end
            ST_STORE_RESULT_A: begin end
            ST_CALC_B: begin
                opmode_x_in = OP_X_IN_MULT;
                opmode_z_in = OP_Z_IN_POUT;
            end
            ST_WAIT_RESULT_B:  begin end
            ST_DONE:           begin end
        endcase
    end


//---------------------------------------------
// -------====== Controll ======-------
//-----------------------------------------

    reg [1:0]  opmode_x_in;
    reg [1:0]  opmode_z_in;
    reg        opmode_use_preadd;
    reg        opmode_cryin;
    reg        opmode_preadd_sub;
    reg        opmode_postadd_sub;

    wire [7:0]  opmode_in = {opmode_postadd_sub, opmode_preadd_sub,
                             opmode_cryin      , opmode_use_preadd,
                             opmode_z_in       , opmode_x_in      };

    reg [7:0] opmode_in_dly;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            opmode_in_dly <= 8'h00;
        end
        else begin
            opmode_in_dly <= opmode_in;
        end
    end

    wire        opmode_postadd_sub_dly = opmode_in_dly[7];
    wire        opmode_preadd_sub_dly  = 1'b0; // opmode_in[6];
    wire        opmode_cryin_dly       = opmode_in_dly[5];
    wire        opmode_use_preadd_dly  = 1'b0; // opmode_in[4];
    wire [1:0]  opmode_z_in_dly        = opmode_in_dly[3:2];
    wire [1:0]  opmode_x_in_dly        = opmode_in_dly[1:0];

    assign  opmode = {opmode_postadd_sub_dly, opmode_preadd_sub_dly,
                      opmode_cryin_dly      , opmode_use_preadd_dly,
                      opmode_z_in_dly       , opmode_x_in_dly      };


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
    wire signed [35:0] m_nc;
    wire signed [17:0] bcout_nc;
    wire signed [47:0] pcout_nc;
    wire signed [47:0] pcin_nc;
    wire               carryin_nc;
    wire               carryout_nc;
    wire               carryoutf_nc;


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
// -------====== Wait Result ======-------
//----------------------------------------------------
    reg [1:0] wait_clac_cnt;
    wire      calc_will_be_done = (wait_clac_cnt == 2'h1);

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            wait_clac_cnt <= 0;
        end
        else if (state == ST_WAIT_RESULT_A || state == ST_WAIT_RESULT_B) begin
            wait_clac_cnt <= wait_clac_cnt + 1;
        end
        else begin
            wait_clac_cnt <= 0;
        end
    end




//--------------------------------------------------------
// -------====== Output ======-------
//----------------------------------------------------
    assign sample_out     = (state == ST_DONE) ? p[33:16] : 18'h00000;
    assign sample_out_rdy = (state == ST_DONE) ? 1 : 0;


//-----------------------------------------------------------------
// -------====== MIDI Events processing ======-------
//-------------------------------------------------------------
    wire      cc_event = (midi_rdy && midi_cmd == `MIDI_CMD_CC);
    reg [7:0] cc_num;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            cc_num <= 0;
        end
        else if (cc_event) begin
            cc_num <= midi_data0;
        end
    end
endmodule
