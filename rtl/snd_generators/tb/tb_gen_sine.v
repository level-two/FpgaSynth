// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: tb_gen_sine.v
// Description: Testbench for the sine generator, NIC and ALU
// -----------------------------------------------------------------------------


`timescale 1ns/100ps

`include "../../globals.vh"

module tb_gen_sine;
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

    reg                      sine_smp_trig;
    wire                     sine_smp_out_rdy;
    wire signed [17:0]       sine_smp_out_l;
    wire signed [17:0]       sine_smp_out_r;
                            
    // ALU                  
    wire                     sine_alu_cycle;
    wire                     sine_alu_strobe;
    wire                     sine_alu_ack;
    wire                     sine_alu_stall;

    wire        [ 8:0]       sine_alu_op;
    wire signed [17:0]       sine_alu_al;
    wire signed [17:0]       sine_alu_bl;
    wire signed [47:0]       sine_alu_cl;
    wire signed [47:0]       sine_alu_pl;
    wire signed [17:0]       sine_alu_ar;
    wire signed [17:0]       sine_alu_br;
    wire signed [47:0]       sine_alu_cr;
    wire signed [47:0]       sine_alu_pr;

    gen_sine gen_sine
    (
        .clk           (clk                     ),
        .reset         (reset                   ),

        .midi_rdy      (midi_rdy                ),
        .midi_cmd      (midi_cmd                ),
        .midi_ch_sysn  (midi_ch_sysn            ),
        .midi_data0    (midi_data0              ),
        .midi_data1    (midi_data1              ),

        .smp_trig      (sine_smp_trig           ),
        .smp_out_rdy   (sine_smp_out_rdy        ),
        .smp_out_l     (sine_smp_out_l          ),
        .smp_out_r     (sine_smp_out_r          ),

        .alu_cycle     (sine_alu_cycle          ),
        .alu_strobe    (sine_alu_strobe         ),
        .alu_ack       (sine_alu_ack            ),
        .alu_stall     (sine_alu_stall          ),
        //.alu_err     (sine_alu_err            ),

        .alu_op        (sine_alu_op             ),
        .alu_al        (sine_alu_al             ),
        .alu_bl        (sine_alu_bl             ),
        .alu_cl        (sine_alu_cl             ),
        .alu_pl        (sine_alu_pl             ),
        .alu_ar        (sine_alu_ar             ),
        .alu_br        (sine_alu_br             ),
        .alu_cr        (sine_alu_cr             ),
        .alu_pr        (sine_alu_pr             ) 
    );


    alu#(
        .CLIENTS_N(1),
        .ALUS_N   (1),
        .ALUS_W   (1)
    ) alu (
        .clk           (clk                     ),
        .reset         (reset                   ),

        .client_cycle  (sine_alu_cycle          ),
        .client_strobe (sine_alu_strobe         ),
        .client_ack    (sine_alu_ack            ),
        .client_stall  (sine_alu_stall          ),
      //.client_err    (sine_alu_err            ),
        .client_op     (sine_alu_op             ),
        .client_al     (sine_alu_al             ),
        .client_bl     (sine_alu_bl             ),
        .client_cl     (sine_alu_cl             ),
        .client_pl     (sine_alu_pl             ),
        .client_ar     (sine_alu_ar             ),
        .client_br     (sine_alu_br             ),
        .client_cr     (sine_alu_cr             ),
        .client_pr     (sine_alu_pr             )
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
        sine_smp_trig   <= 1'b0;

        #100;
        reset           <= 1'b0;
        repeat (10) @(posedge clk);

        midi_rdy        <= 1'b1;
        midi_cmd        <= `MIDI_CMD_NOTE_ON;
        midi_ch_sysn    <= 4'h0;
        midi_data0      <= 7'h50;
        midi_data1      <= 7'h11;
        @(posedge clk);
        midi_rdy        <= 1'b0;
        midi_cmd        <= {`MIDI_CMD_SIZE{1'b0}};
        midi_ch_sysn    <= 4'b0;
        midi_data0      <= 7'b0;
        midi_data1      <= 7'b0;
        sine_smp_trig   <= 1'b0;
        @(posedge clk);

        repeat (100) begin
            sine_smp_trig <= 1'b1;
            @(posedge clk);

            sine_smp_trig <= 1'b0;
            repeat (100) @(posedge clk);
        end

        midi_rdy        <= 1'b1;
        midi_cmd        <= `MIDI_CMD_NOTE_OFF;
        midi_ch_sysn    <= 4'h0;
        midi_data0      <= 7'h50;
        midi_data1      <= 7'h01;
        @(posedge clk);
        midi_rdy        <= 1'b0;
        midi_cmd        <= {`MIDI_CMD_SIZE{1'b0}};
        midi_ch_sysn    <= 4'b0;
        midi_data0      <= 7'b0;
        midi_data1      <= 7'b0;
        sine_smp_trig   <= 1'b0;
        @(posedge clk);


        repeat (100) begin
            sine_smp_trig <= 1'b1;
            @(posedge clk);

            sine_smp_trig <= 1'b0;
            repeat (100) @(posedge clk);
        end


        midi_rdy        <= 1'b1;
        midi_cmd        <= `MIDI_CMD_NOTE_ON;
        midi_ch_sysn    <= 4'h0;
        midi_data0      <= 7'h40;
        midi_data1      <= 7'h21;
        @(posedge clk);
        midi_rdy        <= 1'b0;
        midi_cmd        <= {`MIDI_CMD_SIZE{1'b0}};
        midi_ch_sysn    <= 4'b0;
        midi_data0      <= 7'b0;
        midi_data1      <= 7'b0;
        sine_smp_trig   <= 1'b0;
        @(posedge clk);


        repeat (100) begin
            sine_smp_trig <= 1'b1;
            @(posedge clk);

            sine_smp_trig <= 1'b0;
            repeat (100) @(posedge clk);
        end


//        repeat (100) @(posedge clk);

        $finish;
    end


    always @(posedge clk) begin
        if (sine_smp_out_rdy) begin
            $display("%d", sine_smp_out_l);
        end
    end
endmodule

