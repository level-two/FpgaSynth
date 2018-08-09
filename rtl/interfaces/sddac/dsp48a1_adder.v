// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: dsp48a1_adder.v
// Description: Instance of the DSP48A1 in the 48-bit ADDER/SUBSTRACTER mode
// -----------------------------------------------------------------------------

`include "../globals.vh"

module dsp48a1_adder (
    input                clk,
    input                reset,
    input         [7:0]  opmode,
    input  signed [47:0] dabin,
    input  signed [47:0] cin,
    output signed [47:0] pout
);

    wire signed [17:0] ain;
    wire signed [17:0] bin;
    wire signed [17:0] din;
    assign {din, ain, bin} = {6'h0, dabin[47:0]};

    // not connected
    wire signed [47:0] pcin_nc    = 0;
    wire               carryin_nc = 0;

    wire signed [17:0] bcout_nc;
    wire signed [47:0] pcout_nc;
    wire signed [35:0] m_nc;
    wire               carryout_nc;
    wire               carryoutf_nc;

    DSP48A1 #(
        .A0REG      (0          ),  // First stage A pipeline register (0/1)
        .A1REG      (0          ),  // Second stage A pipeline register (0/1)
        .B0REG      (0          ),  // First stage B pipeline register (0/1)
        .B1REG      (0          ),  // Second stage B pipeline register (0/1)
        .CARRYINREG (0          ),  // CARRYIN pipeline register (0/1)
        .CARRYINSEL ("OPMODE5"  ),  // Specify carry-in source, "CARRYIN" or "OPMODE5" 
        .CARRYOUTREG(0          ),  // CARRYOUT output pipeline register (0/1)
        .CREG       (0          ),  // C pipeline register (0/1)
        .DREG       (0          ),  // D pre-adder pipeline register (0/1)
        .MREG       (0          ),  // M pipeline register (0/1)
        .OPMODEREG  (0          ),  // Enable=1/disable=0 OPMODE pipeline registers
        .PREG       (1          ),  // P output pipeline register (0/1)
        .RSTTYPE    ("SYNC"     )   // Specify reset type, "SYNC" or "ASYNC" 
    )
    DSP48A1_inst (
        .BCOUT     (bcout_nc    ), // B port cascade output
        .PCOUT     (pcout_nc    ), // P cascade output (if used, connect to PCIN of another DSP48A1)
        .CARRYOUT  (carryout_nc ), // Carry output (if used, connect to CARRYIN pin of another DSP48A1)
        .CARRYOUTF (carryoutf_nc), // Fabric carry output
        .M         (m_nc        ), // Fabric multiplier data output
        .P         (pout        ), // Data output
        .PCIN      (pcin_nc     ), // P cascade (if used, connect to PCOUT of another DSP48A1)
        .CLK       (clk         ), // Clock 
        .OPMODE    (opmode      ), // Operation mode 
        .A         (ain         ), // A data 
        .B         (bin         ), // B data (connected to fabric or BCOUT of adjacent DSP48A1)
        .C         (cin         ), // C data 
        .CARRYIN   (carryin_nc  ), // Carry signal (if used, connect to CARRYOUT pin of another DSP48A1)
        .D         (din         ), // B pre-adder data 
        .CEA       (1'b0        ), // Active high clock enable for A registers
        .CEB       (1'b0        ), // Active high clock enable for B registers
        .CEC       (1'b0        ), // Active high clock enable for C registers
        .CECARRYIN (1'b0        ), // Active high clock enable for CARRYIN registers
        .CED       (1'b0        ), // Active high clock enable for D registers
        .CEM       (1'b0        ), // Active high clock enable for multiplier registers
        .CEOPMODE  (1'b0        ), // Active high clock enable for OPMODE registers
        .CEP       (1'b1        ), // Active high clock enable for P registers
        .RSTA      (1'b0        ), // Reset for A pipeline registers
        .RSTB      (1'b0        ), // Reset for B pipeline registers
        .RSTC      (1'b0        ), // Reset for C pipeline registers
        .RSTCARRYIN(1'b0        ), // Reset for CARRYIN pipeline registers
        .RSTD      (1'b0        ), // Reset for D pipeline registers
        .RSTM      (1'b0        ), // Reset for M pipeline registers
        .RSTOPMODE (1'b0        ), // Reset for OPMODE pipeline registers
        .RSTP      (reset       )  // Reset for P pipeline registers
    );
endmodule

