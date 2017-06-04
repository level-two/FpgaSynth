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
`define CLK_DIV_48K             (CLK_DIV_1536K * CLK_DIV_1536K_48K)

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
`define ALU_TAYLOR_NONE         3'h0
`define ALU_TAYLOR_SIN          3'h1
`define ALU_TAYLOR_COS          3'h2
`define ALU_TAYLOR_INV_1_PLUS_X 3'h3

// DSP48A1 constants
`define DSP_NOP                 8'h00

`define DSP_XIN_ZERO            8'h00
`define DSP_XIN_MULT            8'h01
`define DSP_XIN_POUT            8'h02
`define DSP_XIN_DAB             8'h03

`define DSP_ZIN_ZERO            8'h00
`define DSP_ZIN_PCIN            8'h04
`define DSP_ZIN_POUT            8'h08
`define DSP_ZIN_CIN             8'h0c

`define DSP_USE_PREADD          8'h10

`define DSP_CRYIN               8'h20

`define DSP_PREADD_ADD          8'h00
`define DSP_PREADD_SUB          8'h40

`define DSP_POSTADD_ADD         8'h00
`define DSP_POSTADD_SUB         8'h80


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
