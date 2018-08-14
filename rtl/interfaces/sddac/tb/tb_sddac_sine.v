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

`include "../../../globals.vh"

module tb_gen_sine_mul;
    localparam TIMESTEP = 1e-9;
    localparam CLK_FREQ = 100_000_000;
    real CLK_PERIOD = (1 / (TIMESTEP * CLK_FREQ));
    localparam SAMPLE_CLKS   = 2083;
    localparam DAC_OUT_CLKS  = 8;

    reg                      clk;
    reg                      reset;

    reg                      midi_rdy;
    reg [`MIDI_CMD_SIZE-1:0] midi_cmd;
    reg [3:0]                midi_ch_sysn;
    reg [6:0]                midi_data0;
    reg [6:0]                midi_data1;

    reg                      s_smp_trig;
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


    gen_sine #(.MIDI_CH(0)) gen_sine_1
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


    wire dac_out_l;
    wire dac_out_r;

    sddac sddac (
        .clk           (clk                           ),
        .reset         (reset                         ),
        .sample_in_rdy (s_smp_out_rdy                 ),
        .sample_in_l   (s_smp_out_l                   ),
        .sample_in_r   (s_smp_out_r                   ),
        .dac_out_l     (dac_out_l                     ),
        .dac_out_r     (dac_out_r                     )
    );



    initial $timeformat(-9, 0, " ns", 0);

    initial begin
        clk <= 0;
    end

    always begin
        #(CLK_PERIOD/2) clk = ~clk;
    end

    integer f;
    initial begin
        f = $fopen("c:/output.txt", "w");

        reset           <= 1'b1;
        midi_rdy        <= 1'b0;
        midi_cmd        <= {`MIDI_CMD_SIZE{1'b0}};
        midi_ch_sysn    <= 4'b0;
        midi_data0      <= 7'b0;
        midi_data1      <= 7'b0;
        s_smp_trig      <= 1'b0;

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
        @(posedge clk);


        repeat (100) begin
            s_smp_trig  <= 1'b1;
            @(posedge clk);

            s_smp_trig  <= 1'b0;
            repeat (SAMPLE_CLKS-1) @(posedge clk);
        end


        repeat (100) @(posedge clk);

        $fclose(f);
        $finish;
    end


    always @(posedge clk) begin
        if (s_smp_out_rdy) begin
            $display("%d", s_smp_out_l);
        end
    end


    initial begin
        wait (reset === 1'b0);

        forever begin
            repeat (DAC_OUT_CLKS) @(posedge clk);
            $fwrite(f, "%b\n",  dac_out_l); 
        end
    end



endmodule
