// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: dsp48a1_inst.v
// Description: Instance of the DSP48A1 in the pipelined multiplier-postadder
//              mode
// -----------------------------------------------------------------------------

`include "globals.vh"

module dsp48a1_inst (
    input         clk,
    input         reset,
    input  [91:0] dsp_ins_flat,
    output [47:0] dsp_outs_flat
);

    wire [1:0]   opmode_x_in;
    wire [1:0]   opmode_z_in;
    wire         opmode_use_preadd;
    wire         opmode_cryin;
    wire         opmode_preadd_sub;
    wire         opmode_postadd_sub;
    wire signed [17:0] ain;
    wire signed [17:0] bin;
    wire signed [47:0] cin;
    wire signed [47:0] pout;

    assign {opmode_postadd_sub, opmode_preadd_sub,
            opmode_cryin      , opmode_use_preadd,
            opmode_z_in       , opmode_x_in      ,
            ain               , bin              ,
            cin                                  }
        = dsp_ins_flat[91:0];

    assign dsp_outs_flat = pout;


    reg signed [47:0] cin_reg;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            cin_reg <= 48'h0;
        end 
        else begin
            cin_reg <= cin;
        end
    end


//---------------------------------------------
// -------====== Controll ======-------
//-----------------------------------------
    wire [7:0] opmode_in = {opmode_postadd_sub, opmode_preadd_sub,
                            opmode_cryin      , opmode_use_preadd,
                            opmode_z_in       , opmode_x_in      };

    reg  [7:0] opmode_in_dly;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            opmode_in_dly <= 8'h00;
        end
        else begin
            opmode_in_dly <= opmode_in;
        end
    end

    wire       opmode_postadd_sub_dly = opmode_in_dly[7];
    wire       opmode_preadd_sub_dly  = 1'b0; // opmode_in[6];
    wire       opmode_cryin_dly       = opmode_in_dly[5];
    wire       opmode_use_preadd_dly  = 1'b0; // opmode_in[4];
    wire [1:0] opmode_z_in_dly        = opmode_in_dly[3:2];
    wire [1:0] opmode_x_in_dly        = opmode_in_dly[1:0];

    wire [7:0] opmode = {opmode_postadd_sub_dly, opmode_preadd_sub_dly,
                         opmode_cryin_dly      , opmode_use_preadd_dly,
                         opmode_z_in_dly       , opmode_x_in_dly      };


//----------------------------------
// -------====== ALU ======-------
//------------------------------
    // not connected
    wire signed [47:0] pcin_nc    = 0;
    wire signed [17:0] din_nc     = 18'h00000;
    wire               carryin_nc = 0;

    wire signed [17:0] bcout_nc;
    wire signed [47:0] pcout_nc;
    wire signed [35:0] m_nc;
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
        .CREG       (1          ),  // C pipeline register (0/1)
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
        .P         (pout        ), // Data output
        .PCIN      (pcin_nc     ), // P cascade (if used, connect to PCOUT of another DSP48A1)
        .CLK       (clk         ), // Clock 
        .OPMODE    (opmode      ), // Operation mode 
        .A         (ain         ), // A data 
        .B         (bin         ), // B data (connected to fabric or BCOUT of adjacent DSP48A1)
        .C         (cin_reg     ), // C data 
        .CARRYIN   (carryin_nc  ), // Carry signal (if used, connect to CARRYOUT pin of another DSP48A1)
        .D         (din_nc      ), // B pre-adder data 
        .CEA       (1'b1        ), // Active high clock enable for A registers
        .CEB       (1'b1        ), // Active high clock enable for B registers
        .CEC       (1'b1        ), // Active high clock enable for C registers
        .CECARRYIN (1'b0        ), // Active high clock enable for CARRYIN registers
        .CED       (1'b0        ), // Active high clock enable for D registers
        .CEM       (1'b1        ), // Active high clock enable for multiplier registers
        .CEOPMODE  (1'b1        ), // Active high clock enable for OPMODE registers
        .CEP       (1'b1        ), // Active high clock enable for P registers
        .RSTA      (reset       ), // Reset for A pipeline registers
        .RSTB      (reset       ), // Reset for B pipeline registers
        .RSTC      (reset       ), // Reset for C pipeline registers
        .RSTCARRYIN(1'b0        ), // Reset for CARRYIN pipeline registers
        .RSTD      (1'b0        ), // Reset for D pipeline registers
        .RSTM      (reset       ), // Reset for M pipeline registers
        .RSTOPMODE (reset       ), // Reset for OPMODE pipeline registers
        .RSTP      (reset       )  // Reset for P pipeline registers
    );
endmodule
