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
    output     [0:1] PMOD4,   // dac out
    output     [1:0] LED
);

    wire dac_out_l;
    wire dac_out_r;

    wire   rx       = PMOD3[0];
    assign PMOD4[0] = dac_out_l;
    assign PMOD4[1] = dac_out_r;
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


    wire gen_pulse_smpl_rate_trig;

    ctrl ctrl (
        .clk            (clk                      ),
        .reset          (reset                    ),
        .smpl_rate_trig (gen_pulse_smpl_rate_trig )
    );


    wire               gen_pulse_smpl_out_rdy;
    wire signed [17:0] gen_pulse_smpl_out_l;
    wire signed [17:0] gen_pulse_smpl_out_r;

    gen_pulse gen_pulse (
        .clk             (clk                       ),
        .reset           (reset                     ),
        .midi_rdy        (midi_rdy                  ),
        .midi_cmd        (midi_cmd                  ),
        .midi_ch_sysn    (midi_ch_sysn              ),
        .midi_data0      (midi_data0                ),
        .midi_data1      (midi_data1                ),
        .smpl_rate_trig  (gen_pulse_smpl_rate_trig  ),
        .smpl_out_rdy    (gen_pulse_smpl_out_rdy    ),
        .smpl_out_l      (gen_pulse_smpl_out_l      ),
        .smpl_out_r      (gen_pulse_smpl_out_r      )
    );

//    wire                lpf_smpl_in_rdy_l;
//    wire                lpf_smpl_in_rdy_r;
//    wire                lpf_smpl_out_rdy_l;
//    wire                lpf_smpl_out_rdy_r;
//    wire signed [17:0]  lpf_smpl_in_l;
//    wire signed [17:0]  lpf_smpl_in_r;
//    wire signed [17:0]  lpf_smpl_out_l;
//    wire signed [17:0]  lpf_smpl_out_r;
//    wire                err_overflow_l_nc;
//    wire                err_overflow_r_nc;


//    module_lpf module_lpf_l (
//        .clk            (clk                      ),
//        .reset          (reset                    ),
//        .midi_rdy       (midi_rdy                 ),
//        .midi_cmd       (midi_cmd                 ),
//        .midi_ch_sysn   (midi_ch_sysn             ),
//        .midi_data0     (midi_data0               ),
//        .midi_data1     (midi_data1               ),
//        .sample_in_rdy  (lpf_smpl_in_rdy_l        ),
//        .sample_in      (lpf_smpl_in_l            ),
//
//        .sample_out_rdy (lpf_smpl_out_rdy_l       ),
//        .sample_out     (lpf_smpl_out_l           ),
//
//        .err_overflow   (err_overflow_l_nc        )
//    );

//    module_lpf module_lpf_r (
//        .clk            (clk                      ),
//        .reset          (reset                    ),
//        .midi_rdy       (midi_rdy                 ),
//        .midi_cmd       (midi_cmd                 ),
//        .midi_ch_sysn   (midi_ch_sysn             ),
//        .midi_data0     (midi_data0               ),
//        .midi_data1     (midi_data1               ),
//        .sample_in_rdy  (lpf_smpl_in_rdy_r        ),
//        .sample_in      (lpf_smpl_in_r            ),

//        .sample_out_rdy (lpf_smpl_out_rdy_r       ),
//        .sample_out     (lpf_smpl_out_r           ),

//        .err_overflow   (err_overflow_r_nc        )
//    );


    // dut
    wire               dac_sample_in_rdy = gen_pulse_smpl_out_rdy;
    wire signed [17:0] dac_sample_in_l   = gen_pulse_smpl_out_l;
    wire signed [17:0] dac_sample_in_r   = gen_pulse_smpl_out_r;

    module_stereo_dac_output  stereo_dac_output (
        .clk            (clk               ),
        .reset          (reset             ),
        .sample_in_rdy  (dac_sample_in_rdy ),
        .sample_in_l    (dac_sample_in_l   ),
        .sample_in_r    (dac_sample_in_r   ),
        .dac_out_l      (dac_out_l         ),
        .dac_out_r      (dac_out_r         )
    );
endmodule
