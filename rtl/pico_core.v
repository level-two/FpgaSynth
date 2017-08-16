// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: gen_pulse.v
// Description: Simple pulse generator
// -----------------------------------------------------------------------------

module gen_pulse (
    input                       clk,
    input                       reset,
);

    wire [11:0] address;
    wire [17:0] instruction;
    wire        bram_enable;
    wire [7:0]  in_port;
    wire [7:0]  out_port;
    wire [7:0]  port_id;
    wire        write_strobe;
    wire        k_write_strobe;
    wire        read_strobe;
    wire        interrupt;
    wire        interrupt_ack;
    wire        sleep;

    kcpsm6 #(
        .hwbuild                (8'h00           ),
        .interrupt_vector       (12'h3FF         ),
        .scratch_pad_memory_size(64              ))
    picoblaze (
        .clk                    (clk             ),
        .reset                  (reset           ),
        .address                (address         ),
        .instruction            (instruction     ),
        .bram_enable            (bram_enable     ),
        .in_port                (in_port         ),
        .out_port               (out_port        ),
        .port_id                (port_id         ),
        .write_strobe           (write_strobe    ),
        .k_write_strobe         (k_write_strobe  ),
        .read_strobe            (read_strobe     ),
        .interrupt              (interrupt       ),
        .interrupt_ack          (interrupt_ack   ),
        .sleep                  (sleep           )
    );

    input clka
    input [0 : 0] wea
    input [9 : 0] addra
    input [17 : 0] dina
    output [17 : 0] douta

    ip_bram_1k your_instance_name (
        .clka    (clk           ),
        .wea     (1'b0          ),
        .ena     (bram_enable   ),
        .addra   (address       ),
        .dina    (18'h00000     ),
        .douta   (instruction   ) 
    );
endmodule
