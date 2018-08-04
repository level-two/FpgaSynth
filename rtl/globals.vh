// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: globals.vh
// Description: Global constants and common functions
// -----------------------------------------------------------------------------

`ifndef _MIDI_FPGA_SYNTH_GLOBALS_VH_
`define _MIDI_FPGA_SYNTH_GLOBALS_VH_

`define CLK_FREQ                100_000_000
`define CLK_DIV_1536K           65
`define CLK_DIV_1536K_48K       32
`define CLK_DIV_1536K_96K       16
`define CLK_DIV_48K             (`CLK_DIV_1536K * `CLK_DIV_1536K_48K)
`define CLK_DIV_96K             (`CLK_DIV_1536K * `CLK_DIV_1536K_96K)

`define M_PI                    3.141592

`define MIDI_CMD_NONE           'h00
`define MIDI_CMD_NOTE_ON        'h01
`define MIDI_CMD_NOTE_OFF       'h02
`define MIDI_CMD_AFTERTOUCH     'h03
`define MIDI_CMD_CC             'h04
`define MIDI_CMD_PATCH_CHG      'h05
`define MIDI_CMD_CH_PRESSURE    'h06
`define MIDI_CMD_PITCH_BEND     'h07

`define MIDI_CMD_SYS_EXCL_ST    'h08
`define MIDI_CMD_SYS_TIME_QF    'h09
`define MIDI_CMD_SYS_SONG_POS   'h0a
`define MIDI_CMD_SYS_SONG_SEL   'h0b
`define MIDI_CMD_SYS_TUNE_REQ   'h0c
`define MIDI_CMD_SYS_EXCL_END   'h0d
`define MIDI_CMD_SYS_TIMING_CLK 'h0e
`define MIDI_CMD_SYS_START      'h0f
`define MIDI_CMD_SYS_CONT       'h10
`define MIDI_CMD_SYS_STOP       'h11
`define MIDI_CMD_SYS_ACT_SNS    'h12
`define MIDI_CMD_SYS_RST        'h13

`define MIDI_CMD_SIZE           5

// Functions selectors for the alu_taylor module
`define ALU_MODE_DSP            1'b0
`define ALU_MODE_FUNC           1'b1
                                
`define ALU_FUNC_SIN            9'h101
`define ALU_FUNC_COS            9'h102
`define ALU_FUNC_INV_1_PLUS_X   9'h103

// DSP48A1 constants
`define ALU_DSP_NOP             9'h000

`define ALU_DSP_XIN_ZERO        9'h000
`define ALU_DSP_XIN_MULT        9'h001
`define ALU_DSP_XIN_POUT        9'h002
`define ALU_DSP_XIN_DAB         9'h003

`define ALU_DSP_ZIN_ZERO        9'h000
`define ALU_DSP_ZIN_PCIN        9'h004
`define ALU_DSP_ZIN_POUT        9'h008
`define ALU_DSP_ZIN_CIN         9'h00c

`define ALU_DSP_USE_PREADD      9'h010

`define ALU_DSP_CRYIN           9'h020

`define ALU_DSP_PREADD_ADD      9'h000
`define ALU_DSP_PREADD_SUB      9'h040

`define ALU_DSP_POSTADD_ADD     9'h000
`define ALU_DSP_POSTADD_SUB     9'h080


///// ????
`define NBUFS                   16
`define BUF_SIZE                1024
`define BUF_ID_LOWER_BIT        (clogb2(`BUF_SIZE))

`define FIRST_BASE_BIT          28

`define BUF_MANAGER_BASE        1
`define MEM_BASE                2

`define BUF_MANAGER_BASE_ADDR   (`BUF_MANAGER_BASE << `FIRST_BASE_BIT)
`define MEM_BASE_ADDR           (`MEM_BASE         << `FIRST_BASE_BIT)
`define SPI_BASE_ADDR           (`SPI_BASE         << `FIRST_BASE_BIT)


/*

// ---------------------------------------------------------
function integer addr_base;
    input [31:0] addr;
    begin
        addr_base = addr[31:`FIRST_BASE_BIT];
    end
endfunction


function integer addr_without_base;
    input [31:0] addr;
    begin
        addr_without_base = addr[`FIRST_BASE_BIT-1:0];
    end
endfunction


function integer clogb2;
    input [31:0] value;
    begin
        value = value - 1;
        for (clogb2 = 0; value > 0; clogb2 = clogb2 + 1) begin
            value = value >> 1;
        end
    end
endfunction


function integer addr_for_buf_id;
    input [31:0] buf_id;
    begin
        addr_for_buf_id = `MEM_BASE_ADDR | buf_id << `BUF_ID_LOWER_BIT;
    end
endfunction

*/
 
`endif // _MIDI_FPGA_SYNTH_GLOBALS_VH_
