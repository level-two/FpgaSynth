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

module top (
    input            CLK_50M,
    input      [0:0] PB,
    input      [0:0] PMOD3,   // UART rx
    output     [0:0] PMOD4,   // dac out
    output     [1:0] LED
);

    wire dac_out_l;
    wire dac_out_r;

    wire   rx       = PMOD3[0];
    assign PMOD4[0] = dac_out_l;
    assign LED[0]   = 0;
    assign LED[1]   = 0;

    wire clk;
    wire clk_valid;
    wire reset_n = clk_valid & PB[0];
    wire reset   = ~reset_n;

    ip_clk_gen_100M clk_gen
    (
        .clk_in_50M  (CLK_50M  ), 
        .clk_out_100M(clk      ), 
        .CLK_VALID   (clk_valid)
    );

    wire        data_received;
    wire [7:0]  data;

    wire        midi_rdy;
    wire [`MIDI_CMD_SIZE-1:0] midi_cmd;
    wire [3:0]  midi_ch_sysn;
    wire [6:0]  midi_data0;
    wire [6:0]  midi_data1;

    wire        smpl_rate_trig_l;
    wire        smpl_rate_trig_r;

    uart_rx #(.CLK_FREQ(`CLK_FREQ), .BAUD_RATE(38400)) uart_rx
    (
        .clk          (clk          ),
        .reset        (reset        ),
        .rx           (rx           ),
        .data_received(data_received),
        .data         (data         )
    );


    midi_decoder midi_decoder (
        .clk         (clk          ),
        .reset       (reset        ),
        .dataInReady (data_received),
        .dataIn      (data         ),

        .midi_rdy    (midi_rdy     ),
        .midi_cmd    (midi_cmd     ),
        .midi_ch_sysn(midi_ch_sysn ),
        .midi_data0  (midi_data0   ),
        .midi_data1  (midi_data1   )
    );


    ctrl ctrl (
        .clk             (clk             ),
        .reset           (reset           ),
        .smpl_rate_trig_l(smpl_rate_trig_l),
        .smpl_rate_trig_r(smpl_rate_trig_r)
    );


    wire                lpf_smpl_in_rdy_l;
    wire                lpf_smpl_in_rdy_r;
    wire                lpf_smpl_out_rdy_l;
    wire                lpf_smpl_out_rdy_r;
    wire signed [17:0]  lpf_smpl_in_l;
    wire signed [17:0]  lpf_smpl_in_r;
    wire signed [17:0]  lpf_smpl_out_l;
    wire signed [17:0]  lpf_smpl_out_r;
    wire                err_overflow_l_nc;
    wire                err_overflow_r_nc;

    gen_pulse gen_pulse (
        .clk             (clk               ),
        .reset           (reset             ),
        .midi_rdy        (midi_rdy          ),
        .midi_cmd        (midi_cmd          ),
        .midi_ch_sysn    (midi_ch_sysn      ),
        .midi_data0      (midi_data0        ),
        .midi_data1      (midi_data1        ),
        .smpl_rate_trig_l(smpl_rate_trig_l  ),
        .smpl_rate_trig_r(smpl_rate_trig_r  ),
//        .smpl_out_rdy_l  (lpf_smpl_out_rdy_l ),
//        .smpl_out_l      (lpf_smpl_out_l     ),
//        .smpl_out_rdy_r  (lpf_smpl_out_rdy_r ),
//        .smpl_out_r      (lpf_smpl_out_r     )
        .smpl_out_rdy_l  (lpf_smpl_in_rdy_l ),
        .smpl_out_l      (lpf_smpl_in_l     ),
        .smpl_out_rdy_r  (lpf_smpl_in_rdy_r ),
        .smpl_out_r      (lpf_smpl_in_r     )
    );


    module_lpf module_lpf_l (
        .clk            (clk                      ),
        .reset          (reset                    ),
        .midi_rdy       (midi_rdy                 ),
        .midi_cmd       (midi_cmd                 ),
        .midi_ch_sysn   (midi_ch_sysn             ),
        .midi_data0     (midi_data0               ),
        .midi_data1     (midi_data1               ),
        .sample_in_rdy  (lpf_smpl_in_rdy_l        ),
        .sample_in      (lpf_smpl_in_l            ),
//
        .sample_out_rdy (lpf_smpl_out_rdy_l       ),
        .sample_out     (lpf_smpl_out_l           ),
//
        .err_overflow   (err_overflow_l_nc        )
    );

    module_lpf module_lpf_r (
        .clk            (clk                      ),
        .reset          (reset                    ),
        .midi_rdy       (midi_rdy                 ),
        .midi_cmd       (midi_cmd                 ),
        .midi_ch_sysn   (midi_ch_sysn             ),
        .midi_data0     (midi_data0               ),
        .midi_data1     (midi_data1               ),
        .sample_in_rdy  (lpf_smpl_in_rdy_r        ),
        .sample_in      (lpf_smpl_in_r            ),
//
        .sample_out_rdy (lpf_smpl_out_rdy_r       ),
        .sample_out     (lpf_smpl_out_r           ),
//
        .err_overflow   (err_overflow_r_nc        )
    );


    sigma_delta_2order_dac  sigma_delta_2order_dac_l
    (
        .clk              (clk                  ),
        .reset            (reset                ),
        .sample_in        (lpf_smpl_out_l       ),
        .sample_in_rdy    (lpf_smpl_out_rdy_l   ),
        .sample_rate_trig (smpl_rate_trig_l     ),
        .dout             (dac_out_l            )
    );

    sigma_delta_2order_dac  sigma_delta_2order_dac_r
    (
        .clk              (clk                  ),
        .reset            (reset                ),
        .sample_in        (lpf_smpl_out_r       ),
        .sample_in_rdy    (lpf_smpl_out_rdy_r   ),
        .sample_rate_trig (smpl_rate_trig_r     ),
        .dout             (dac_out_r            )
    );
endmodule
