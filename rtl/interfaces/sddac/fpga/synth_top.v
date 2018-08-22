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

    // sigma-delta DAC out
    output       dac_out,
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
        .clk           (clk                         ),
        .reset         (reset                       ),
        .rx            (uart_rx                     ),
        .data_received (uart_data_rdy               ),
        .data          (uart_data                   )
    );


    midi_decoder midi_decoder_inst (
        .clk           (clk                         ),
        .reset         (reset                       ),
        .dataInReady   (uart_data_rdy               ),
        .dataIn        (uart_data                   ),

        .midi_rdy      (midi_rdy                    ),
        .midi_cmd      (midi_cmd                    ),
        .midi_ch_sysn  (midi_ch_sysn                ),
        .midi_data0    (midi_data0                  ),
        .midi_data1    (midi_data1                  )
    );


    reg [11:0] s_smp_trig_cnt;
    wire       s_smp_trig = (s_smp_trig_cnt == 16'h0001);

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            s_smp_trig_cnt <= 12'd0;
        end else if (s_smp_trig_cnt == 12'd2082) begin
            s_smp_trig_cnt <= 12'd0;
        end else begin
            s_smp_trig_cnt <= s_smp_trig_cnt + 12'd1;
        end
    end


    wire                     s_smp_out_rdy;
    wire signed [17:0]       s_smp_out_l;
    wire signed [17:0]       s_smp_out_r;
                            
    wire                     s_alu_cycle;
    wire                     s_alu_strobe;
    wire                     s_alu_ack;
    wire                     s_alu_stall;

    wire        [ 8:0]       s_alu_op;
    wire signed [17:0]       s_alu_al;
    wire signed [17:0]       s_alu_bl;
    wire signed [47:0]       s_alu_cl;
    wire signed [47:0]       s_alu_pl;
    wire signed [17:0]       s_alu_ar;
    wire signed [17:0]       s_alu_br;
    wire signed [47:0]       s_alu_cr;
    wire signed [47:0]       s_alu_pr;


    gen_sine #(.MIDI_CH(0)) gen_sine
    (
        .clk           (clk                     ),
        .reset         (reset                   ),

        .midi_rdy      (midi_rdy                ),
        .midi_cmd      (midi_cmd                ),
        .midi_ch_sysn  (midi_ch_sysn            ),
        .midi_data0    (midi_data0              ),
        .midi_data1    (midi_data1              ),

        .smp_trig      (s_smp_trig              ),
        .smp_out_rdy   (s_smp_out_rdy           ),
        .smp_out_l     (s_smp_out_l             ),
        .smp_out_r     (s_smp_out_r             ),

        .alu_cycle     (s_alu_cycle             ),
        .alu_strobe    (s_alu_strobe            ),
        .alu_ack       (s_alu_ack               ),
        .alu_stall     (s_alu_stall             ),
        //.alu_err     (s_alu_err               ),

        .alu_op        (s_alu_op                ),
        .alu_al        (s_alu_al                ),
        .alu_bl        (s_alu_bl                ),
        .alu_cl        (s_alu_cl                ),
        .alu_pl        (s_alu_pl                ),
        .alu_ar        (s_alu_ar                ),
        .alu_br        (s_alu_br                ),
        .alu_cr        (s_alu_cr                ),
        .alu_pr        (s_alu_pr                ) 
    );


    alu #(
        .CLIENTS_N(1),
        .ALUS_N   (1),
        .ALUS_W   (1)
    ) alu (
        .clk           (clk                           ),
        .reset         (reset                         ),

        .client_cycle  (s_alu_cycle                   ),
        .client_strobe (s_alu_strobe                  ),
        .client_ack    (s_alu_ack                     ),
        .client_stall  (s_alu_stall                   ),
      //.client_err    (s_alu_err                     ),
        .client_op     (s_alu_op                      ),
        .client_al     (s_alu_al                      ),
        .client_bl     (s_alu_bl                      ),
        .client_cl     (s_alu_cl                      ),
        .client_pl     (s_alu_pl                      ),
        .client_ar     (s_alu_ar                      ),
        .client_br     (s_alu_br                      ),
        .client_cr     (s_alu_cr                      ),
        .client_pr     (s_alu_pr                      )
    );


    wire dac_out_r_nc;

    sddac sddac (
        .clk           (clk                           ),
        .reset         (reset                         ),
        .sample_in_rdy (s_smp_out_rdy                 ),
        .sample_in_l   (s_smp_out_l                   ),
        .sample_in_r   (s_smp_out_r                   ),
        .dac_out_l     (dac_out                       ),
        .dac_out_r     (dac_out_r_nc                  )
    );

endmodule
