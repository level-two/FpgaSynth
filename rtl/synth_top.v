// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: top.v
// Description: Top level module with external FPGA interface
// -----------------------------------------------------------------------------

`include "globals.vh"

module synth_top (
    input        clk,
    input        reset,
    input        uart_rx,

    input        i2s_lrclk_in,
    input        i2s_bclk_in,
    input        i2s_data_in,
    output       i2s_data_out
);

    wire        uart_data_rdy;
    wire [7:0]  uart_data;

    wire        midi_rdy;
    wire [`MIDI_CMD_SIZE-1:0] midi_cmd;
    wire [3:0]  midi_ch_sysn;
    wire [6:0]  midi_data0;
    wire [6:0]  midi_data1;


    uart_rx #(.CLK_FREQ(`CLK_FREQ), .BAUD_RATE(38400)) uart_rx_inst
    (
        .clk          (clk          ),
        .reset        (reset        ),
        .rx           (uart_rx      ),
        .data_received(uart_data_rdy),
        .data         (uart_data    )
    );


    midi_decoder midi_decoder_inst (
        .clk         (clk          ),
        .reset       (reset        ),
        .dataInReady (uart_data_rdy),
        .dataIn      (uart_data    ),

        .midi_rdy    (midi_rdy     ),
        .midi_cmd    (midi_cmd     ),
        .midi_ch_sysn(midi_ch_sysn ),
        .midi_data0  (midi_data0   ),
        .midi_data1  (midi_data1   )
    );


    wire               new_sample_trig;

    wire               pgen_smp_out_rdy;
    wire signed [17:0] pgen_smp_out_l;
    wire signed [17:0] pgen_smp_out_r;
    wire [47:0]        pgen_dsp_outs_flat_l = dsp_outs_flat_l;
    wire [47:0]        pgen_dsp_outs_flat_r = dsp_outs_flat_r;
    wire [91:0]        pgen_dsp_ins_flat_l;
    wire [91:0]        pgen_dsp_ins_flat_r;

    gen_pulse gen_pulse_inst (
        .clk                  (clk                       ),
        .reset                (reset                     ),
        .midi_rdy             (midi_rdy                  ),
        .midi_cmd             (midi_cmd                  ),
        .midi_ch_sysn         (midi_ch_sysn              ),
        .midi_data0           (midi_data0                ),
        .midi_data1           (midi_data1                ),
        .smp_rate_2x_trig     (new_sample_trig           ),
        .smp_out_rdy          (pgen_smp_out_rdy          ),
        .smp_out_l            (pgen_smp_out_l            ),
        .smp_out_r            (pgen_smp_out_r            ),
        .dsp_outs_flat_l      (pgen_dsp_outs_flat_l      ),
        .dsp_outs_flat_r      (pgen_dsp_outs_flat_r      ),
        .dsp_ins_flat_l       (pgen_dsp_ins_flat_l       ),
        .dsp_ins_flat_r       (pgen_dsp_ins_flat_r       )
    );

    wire                lpf_smp_in_rdy;
    wire signed [17:0]  lpf_smp_l_in;
    wire signed [17:0]  lpf_smp_r_in;
    wire                lpf_smp_out_rdy;
    wire signed [17:0]  lpf_smp_l_out;
    wire signed [17:0]  lpf_smp_r_out;
    wire                err_overflow_nc;

    module_lpf module_lpf_inst (
        .clk           (clk                      ),
        .reset         (reset                    ),
        .midi_rdy      (midi_rdy                 ),
        .midi_cmd      (midi_cmd                 ),
        .midi_ch_sysn  (midi_ch_sysn             ),
        .midi_data0    (midi_data0               ),
        .midi_data1    (midi_data1               ),
        .smp_in_rdy    (lpf_smp_in_rdy           ),
        .smp_l_in      (lpf_smp_l_in             ),
        .smp_r_in      (lpf_smp_r_in             ),
        .smp_out_rdy   (lpf_smp_out_rdy          ),
        .smp_l_out     (lpf_smp_l_out            ),
        .smp_r_out     (lpf_smp_r_out            ),
        .err_overflow  (err_overflow_nc          ),

        .dsp_hp_op     (lpf_dsp_hp_op            ),
        .dsp_hp_al     (lpf_dsp_hp_al            ),
        .dsp_hp_bl     (lpf_dsp_hp_bl            ),
        .dsp_hp_cl     (lpf_dsp_hp_cl            ),
        .dsp_hp_pl     (lpf_dsp_hp_pl            ),
        .dsp_hp_ar     (lpf_dsp_hp_ar            ),
        .dsp_hp_br     (lpf_dsp_hp_br            ),
        .dsp_hp_cr     (lpf_dsp_hp_cr            ),
        .dsp_hp_pr     (lpf_dsp_hp_pr            ),
        .dsp_hp_req    (lpf_dsp_hp_req           ),
        .dsp_hp_gnt    (lpf_dsp_hp_gnt           ),

        .dsp_lp_op     (lpf_dsp_lp_op            ),
        .dsp_lp_al     (lpf_dsp_lp_al            ),
        .dsp_lp_bl     (lpf_dsp_lp_bl            ),
        .dsp_lp_cl     (lpf_dsp_lp_cl            ),
        .dsp_lp_pl     (lpf_dsp_lp_pl            ),
        .dsp_lp_ar     (lpf_dsp_lp_ar            ),
        .dsp_lp_br     (lpf_dsp_lp_br            ),
        .dsp_lp_cr     (lpf_dsp_lp_cr            ),
        .dsp_lp_pr     (lpf_dsp_lp_pr            ),
        .dsp_lp_req    (lpf_dsp_lp_req           ),
        .dsp_lp_gnt    (lpf_dsp_lp_gnt           )
    );

    // DSP signals interconnection
    dsp_module #(
        .CLIENTS_N(2                  ),
        .DSPS_N   (1                  )
    ) dsp_module_inst (
        .clk    ( clk                 ),
        .reset  ( reset               ),
        .op     ( {lpf_op , pgen_op } ),
        .al     ( {lpf_al , pgen_al } ),
        .bl     ( {lpf_bl , pgen_bl } ),
        .cl     ( {lpf_cl , pgen_cl } ),
        .pl     ( {lpf_pl , pgen_pl } ),
        .ar     ( {lpf_ar , pgen_ar } ),
        .br     ( {lpf_br , pgen_br } ),
        .cr     ( {lpf_cr , pgen_cr } ),
        .pr     ( {lpf_pr , pgen_pr } ),
        .req    ( {lpf_req, pgen_req} ),
        .gnt    ( {lpf_gnt, pgen_gnt} )
    );


    wire               i2s_sample_in_rdy = pgen_smp_out_rdy;
    wire signed [17:0] i2s_sample_in_l   = pgen_smp_out_l;
    wire signed [17:0] i2s_sample_in_r   = pgen_smp_out_r;

    module_i2s_output  module_i2s_output
    (
        .clk            (clk               ),
        .reset          (reset             ),
        .sample_in_rdy  (i2s_sample_in_rdy ),
        .sample_in_l    (i2s_sample_in_l   ),
        .sample_in_r    (i2s_sample_in_r   ),
        .data_sampled   (new_sample_trig   ),
        .bclk           (i2s_bclk_in       ),
        .lrclk          (i2s_lrclk_in      ),
        .dacda          (i2s_data_out      )
    );
endmodule
