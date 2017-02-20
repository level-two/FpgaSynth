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







//------------------------------------
// -------====== COEFS ======-------
//--------------------------------

    reg [1:0] coef_sel;

    reg signed [17:0] a_coef;
    always (@coef_sel) begin
        case (coef_sel)
            2'h0: begin a_coef <= 18'h00000; end
            2'h1: begin a_coef <= 18'h00000; end
            2'h2: begin a_coef <= 18'h00000; end
            2'h3: begin a_coef <= 18'h00000; end
            default: begin a_coef <= 18'h00000; end
        endcase
    end

    reg signed [17:0] b_coef;
    always (@coef_sel) begin
        case (coef_sel)
            2'h0: begin b_coef <= 18'h00000; end
            2'h1: begin b_coef <= 18'h00000; end
            2'h2: begin b_coef <= 18'h00000; end
            2'h3: begin b_coef <= 18'h00000; end
            default: begin b_coef <= 18'h00000; end
        endcase
    end


    dp_ram #(.DATA_WIDTH(18), .ADDR_WIDTH(3)) dp_ram
    (
        .clk    (clk          ),
        .rd     (omega_rd     ),
        .rd_addr(omega_rd_addr),
        .rd_data(omega_rd_data),
        .wr     (omega_wr     ),
        .wr_addr(omega_wr_addr),
        .wr_data(omega_wr_data)
    );


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

    wire [1:0]  opmode_x_in;
    wire [1:0]  opmode_z_in;
    wire        opmode_use_preadd;
    wire        opmode_cryin = 1'b0;
    wire        opmode_preadd_nsub;
    wire        opmode_postadd_nsub;

    wire [7:0]  opmode = {opmode_postadd_nsub, opmode_preadd_nsub, opmode_cryin,
                          opmode_use_preadd  , opmode_z_in       , opmode_x_in};

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
        .D         (18'b0      ), // B pre-adder data 
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
				











    // TODO: Use this
    wire cc_event  = (midi_rdy && midi_cmd == `MIDI_CMD_CC);

    reg [7:0] cc_num;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            cc_num <= 0;
        end
        else if (note_on_event) begin
            cc_num <= midi_data0;
        end
    end


    
    // TODO: Use this
    wire processing_done = (state == ST_DONE);
    wire sample_val = p;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            sample_out     <= 18'b0;
            sample_out_rdy <= 0;
        end
        else if (processing_done) begin
            sample_out     <= sample_val;
            sample_out_rdy <= 1;
        end
        else begin
            sample_out_rdy <= 0;
        end
    end
endmodule
