// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: tb_gen_sine_mul.v
// Description: Testbench for the sine generator, NIC and ALU
// -----------------------------------------------------------------------------


`timescale 1ns/100ps

`include "../../globals.vh"

module tb_gen_sine_mul;
    localparam TIMESTEP = 1e-9;
    localparam CLK_FREQ = 100_000_000;
    real CLK_PERIOD = (1 / (TIMESTEP * CLK_FREQ));

    reg                      clk;
    reg                      reset;

    reg                      midi_rdy;
    reg [`MIDI_CMD_SIZE-1:0] midi_cmd;
    reg [3:0]                midi_ch_sysn;
    reg [6:0]                midi_data0;
    reg [6:0]                midi_data1;

    reg                      s1_smp_trig;
    wire                     s1_smp_out_rdy;
    wire signed [17:0]       s1_smp_out_l;
    wire signed [17:0]       s1_smp_out_r;
                            
    wire                     s1_alu_cycle;
    wire                     s1_alu_strobe;
    wire                     s1_alu_ack;
    wire                     s1_alu_stall;

    wire        [ 8:0]       s1_alu_op;
    wire signed [17:0]       s1_alu_al;
    wire signed [17:0]       s1_alu_bl;
    wire signed [47:0]       s1_alu_cl;
    wire signed [47:0]       s1_alu_pl;
    wire signed [17:0]       s1_alu_ar;
    wire signed [17:0]       s1_alu_br;
    wire signed [47:0]       s1_alu_cr;
    wire signed [47:0]       s1_alu_pr;

    reg                      s2_smp_trig;
    wire                     s2_smp_out_rdy;
    wire signed [17:0]       s2_smp_out_l;
    wire signed [17:0]       s2_smp_out_r;

    wire                     s2_alu_cycle;
    wire                     s2_alu_strobe;
    wire                     s2_alu_ack;
    wire                     s2_alu_stall;

    wire        [ 8:0]       s2_alu_op;
    wire signed [17:0]       s2_alu_al;
    wire signed [17:0]       s2_alu_bl;
    wire signed [47:0]       s2_alu_cl;
    wire signed [47:0]       s2_alu_pl;
    wire signed [17:0]       s2_alu_ar;
    wire signed [17:0]       s2_alu_br;
    wire signed [47:0]       s2_alu_cr;
    wire signed [47:0]       s2_alu_pr;


    gen_sine #(.MIDI_CH(0)) gen_sine_1
    (
        .clk           (clk                     ),
        .reset         (reset                   ),

        .midi_rdy      (midi_rdy                ),
        .midi_cmd      (midi_cmd                ),
        .midi_ch_sysn  (midi_ch_sysn            ),
        .midi_data0    (midi_data0              ),
        .midi_data1    (midi_data1              ),

        .smp_trig      (s1_smp_trig             ),
        .smp_out_rdy   (s1_smp_out_rdy          ),
        .smp_out_l     (s1_smp_out_l            ),
        .smp_out_r     (s1_smp_out_r            ),
                                                
        .alu_cycle     (s1_alu_cycle            ),
        .alu_strobe    (s1_alu_strobe           ),
        .alu_ack       (s1_alu_ack              ),
        .alu_stall     (s1_alu_stall            ),
        //.alu_err     (s1_alu_err              ),
                                                
        .alu_op        (s1_alu_op               ),
        .alu_al        (s1_alu_al               ),
        .alu_bl        (s1_alu_bl               ),
        .alu_cl        (s1_alu_cl               ),
        .alu_pl        (s1_alu_pl               ),
        .alu_ar        (s1_alu_ar               ),
        .alu_br        (s1_alu_br               ),
        .alu_cr        (s1_alu_cr               ),
        .alu_pr        (s1_alu_pr               ) 
    );


    gen_sine #(.MIDI_CH(1)) gen_sine_2
    (
        .clk           (clk                     ),
        .reset         (reset                   ),

        .midi_rdy      (midi_rdy                ),
        .midi_cmd      (midi_cmd                ),
        .midi_ch_sysn  (midi_ch_sysn            ),
        .midi_data0    (midi_data0              ),
        .midi_data1    (midi_data1              ),

        .smp_trig      (s2_smp_trig             ),
        .smp_out_rdy   (s2_smp_out_rdy          ),
        .smp_out_l     (s2_smp_out_l            ),
        .smp_out_r     (s2_smp_out_r            ),

        .alu_cycle     (s2_alu_cycle            ),
        .alu_strobe    (s2_alu_strobe           ),
        .alu_ack       (s2_alu_ack              ),
        .alu_stall     (s2_alu_stall            ),
        //.alu_err     (s2_alu_err              ),

        .alu_op        (s2_alu_op               ),
        .alu_al        (s2_alu_al               ),
        .alu_bl        (s2_alu_bl               ),
        .alu_cl        (s2_alu_cl               ),
        .alu_pl        (s2_alu_pl               ),
        .alu_ar        (s2_alu_ar               ),
        .alu_br        (s2_alu_br               ),
        .alu_cr        (s2_alu_cr               ),
        .alu_pr        (s2_alu_pr               ) 
    );




    alu#(
        .CLIENTS_N(2),
        .ALUS_N   (1),
        .ALUS_W   (1)
    ) alu (
        .clk           (clk                           ),
        .reset         (reset                         ),

        .client_cycle  ({s1_alu_cycle , s2_alu_cycle }),
        .client_strobe ({s1_alu_strobe, s2_alu_strobe}),
        .client_ack    ({s1_alu_ack   , s2_alu_ack   }),
        .client_stall  ({s1_alu_stall , s2_alu_stall }),
      //.client_err    ({s1_alu_err   , s2_alu_err   }),
        .client_op     ({s1_alu_op    , s2_alu_op    }),
        .client_al     ({s1_alu_al    , s2_alu_al    }),
        .client_bl     ({s1_alu_bl    , s2_alu_bl    }),
        .client_cl     ({s1_alu_cl    , s2_alu_cl    }),
        .client_pl     ({s1_alu_pl    , s2_alu_pl    }),
        .client_ar     ({s1_alu_ar    , s2_alu_ar    }),
        .client_br     ({s1_alu_br    , s2_alu_br    }),
        .client_cr     ({s1_alu_cr    , s2_alu_cr    }),
        .client_pr     ({s1_alu_pr    , s2_alu_pr    })
    );

    
    initial $timeformat(-9, 0, " ns", 0);

    initial begin
        clk <= 0;
    end

    always begin
        #(CLK_PERIOD/2) clk = ~clk;
    end

    initial begin
        reset           <= 1'b1;
        midi_rdy        <= 1'b0;
        midi_cmd        <= {`MIDI_CMD_SIZE{1'b0}};
        midi_ch_sysn    <= 4'b0;
        midi_data0      <= 7'b0;
        midi_data1      <= 7'b0;
        s1_smp_trig     <= 1'b0;
        s2_smp_trig     <= 1'b0;

        #100;
        reset           <= 1'b0;
        repeat (10) @(posedge clk);


        midi_rdy        <= 1'b1;
        midi_cmd        <= `MIDI_CMD_NOTE_ON;
        midi_ch_sysn    <= 4'h0;
        midi_data0      <= 7'h50;
        midi_data1      <= 7'h11;
        @(posedge clk);
        midi_rdy        <= 1'b1;
        midi_cmd        <= `MIDI_CMD_NOTE_ON;
        midi_ch_sysn    <= 4'h1;
        midi_data0      <= 7'h60;
        midi_data1      <= 7'h21;
        @(posedge clk);
        midi_rdy        <= 1'b0;
        midi_cmd        <= {`MIDI_CMD_SIZE{1'b0}};
        midi_ch_sysn    <= 4'b0;
        midi_data0      <= 7'b0;
        midi_data1      <= 7'b0;
        s1_smp_trig     <= 1'b0;
        s2_smp_trig     <= 1'b0;
        @(posedge clk);


        repeat (100) begin
            s1_smp_trig <= 1'b1;
            s2_smp_trig <= 1'b1;
            @(posedge clk);

            s1_smp_trig <= 1'b0;
            s2_smp_trig <= 1'b0;
            repeat (200) @(posedge clk);
        end


//        repeat (100) @(posedge clk);

        $finish;
    end


    always @(posedge clk) begin
        if (s1_smp_out_rdy) begin
            $display("%d", s1_smp_out_l);
        end
    end
endmodule


