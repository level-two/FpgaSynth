// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: module_stereo_dac_output.v
// Description: Stereo sigma-delta dac with interpolation
//              Input  sample rate:   48 kHz
//              Output sample rate: 1536 kHz
// -----------------------------------------------------------------------------

`include "globals.vh"

module module_stereo_dac_output (
    input               clk,
    input               reset,
    input               sample_in_rdy,
    input signed [17:0] sample_in_l,
    input signed [17:0] sample_in_r,
    output              dac_out_l,
    output              dac_out_r
);


    // TASKS
    localparam [7:0] NOP       = 8'h00;
    localparam [7:0] WAIT_IN   = 8'h01;
    localparam [7:0] WAIT_DONE = 8'h02;
    localparam [7:0] SEND_1_2  = 8'h04;
    localparam [7:0] SEND_2_3  = 8'h08;
    localparam [7:0] JP_0      = 8'h10;


    reg [7:0] tasks;
    always @(*) begin
        case (pc)
            4'h0   : tasks = WAIT_IN    ;
            4'h1   : tasks = WAIT_DONE  ;
            4'h2   : tasks = SEND_1_2   ;
            4'h3   : tasks = WAIT_DONE  ;
            4'h4   : tasks = SEND_1_2   ;
            4'h5   : tasks = WAIT_DONE  ;
            4'h6   : tasks = SEND_2_3   ;
            4'h7   : tasks = WAIT_DONE  ;
            4'h8   : tasks = SEND_2_3   ;
            4'h9   : tasks = WAIT_DONE  ;
            4'ha   : tasks = SEND_2_3   ;
            4'hb   : tasks = WAIT_DONE  ;
            4'hc   : tasks = SEND_2_3   ;
            4'hd   : tasks = WAIT_DONE  ;
            4'he   : tasks = JP_0       ;
            default: tasks = JP_0       ;
        endcase
    end


    // PC
    reg [3:0] pc;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            pc <= 4'h0;
        end
        else if (tasks & JP_0) begin
            pc <= 4'h0;
        end
        else if ((tasks & WAIT_IN   && !sample_in_rdy) ||
                 (tasks & WAIT_DONE && !done         )) begin
            pc <= pc;
        end
        else begin
            pc <= pc + 4'h1;
        end
    end


    // FIFO 1->2
    wire        fifo_1_2_wr      = i1_sample_out_rdy;
    wire [35:0] fifo_1_2_data_in = {i1_sample_out_l, i1_sample_out_r}; 
    wire        fifo_1_2_rd      = (tasks & SEND_1_2) ? 1'b1 : 1'b0;
    wire [35:0] fifo_1_2_data_out;
    wire        fifo_1_2_empty;
    wire        fifo_1_2_full;

    syn_fifo #(36, 1, 2) fifo_1_2 (
        .clk        (clk                ),
        .rst        (reset              ),
        .wr         (fifo_1_2_wr        ),
        .rd         (fifo_1_2_rd        ),
        .data_in    (fifo_1_2_data_in   ),
        .data_out   (fifo_1_2_data_out  ),
        .empty      (fifo_1_2_empty     ),
        .full       (fifo_1_2_full      )      
    );


    // FIFO 2->3
    wire        fifo_2_3_wr      = i2_sample_out_rdy;
    wire [35:0] fifo_2_3_data_in = {i2_sample_out_l, i2_sample_out_r};
    wire        fifo_2_3_rd      = (tasks & SEND_2_3) ? 1'b1 : 1'b0;
    wire [35:0] fifo_2_3_data_out;
    wire        fifo_2_3_empty;
    wire        fifo_2_3_full;

    syn_fifo #(36, 2, 4) fifo_2_3 (
        .clk        (clk                ),
        .rst        (reset              ),
        .wr         (fifo_2_3_wr        ),
        .rd         (fifo_2_3_rd        ),
        .data_in    (fifo_2_3_data_in   ),
        .data_out   (fifo_2_3_data_out  ),
        .empty      (fifo_2_3_empty     ),
        .full       (fifo_2_3_full      )      
    );


    // FIFO 3 to DAC
    wire        fifo_3_dac_wr      = i3_sample_out_rdy;
    wire [35:0] fifo_3_dac_data_in = {i3_sample_out_l, i3_sample_out_r};
    wire        fifo_3_dac_rd      = dac_rd_next_sample;
    wire [35:0] fifo_3_dac_data_out;
    wire        fifo_3_dac_empty;
    wire        fifo_3_dac_full;

    syn_fifo #(36, 5, 40) fifo_3_4 (
        .clk        (clk                  ),
        .rst        (reset                ),
        .wr         (fifo_3_dac_wr        ),
        .rd         (fifo_3_dac_rd        ),
        .data_in    (fifo_3_dac_data_in   ),
        .data_out   (fifo_3_dac_data_out  ),
        .empty      (fifo_3_dac_empty     ),
        .full       (fifo_3_dac_full      )      
    );


    // INTERPOLATING FILTERS
    wire               i1_sample_in_rdy = sample_in_rdy;
    wire signed [17:0] i1_sample_in_l   = sample_in_l;
    wire signed [17:0] i1_sample_in_r   = sample_in_r;
    wire               i1_sample_out_rdy;
    wire signed [17:0] i1_sample_out_l;
    wire signed [17:0] i1_sample_out_r;
    wire               i1_done;
    wire [91:0]        i1_dsp_ins_flat_l;
    wire [91:0]        i1_dsp_ins_flat_r;
    wire [47:0]        i1_dsp_outs_flat_l = dsp_outs_flat_l;
    wire [47:0]        i1_dsp_outs_flat_r = dsp_outs_flat_r;

    fir_interp_halfband_2x  i1_48k_96k (
        .clk             (clk                   ),
        .reset           (reset                 ),
        .sample_in_rdy   (i1_sample_in_rdy      ),
        .sample_in_l     (i1_sample_in_l        ),
        .sample_in_r     (i1_sample_in_r        ),
        .sample_out_rdy  (i1_sample_out_rdy     ),
        .sample_out_l    (i1_sample_out_l       ),
        .sample_out_r    (i1_sample_out_r       ),
        .done            (i1_done               ),
        .dsp_outs_flat_l (i1_dsp_outs_flat_l    ),
        .dsp_outs_flat_r (i1_dsp_outs_flat_r    ),
        .dsp_ins_flat_l  (i1_dsp_ins_flat_l     ),
        .dsp_ins_flat_r  (i1_dsp_ins_flat_r     )
    );

    wire               i2_sample_in_rdy = fifo_1_2_rd;
    wire signed [17:0] i2_sample_in_l = fifo_1_2_data_out[35:18];
    wire signed [17:0] i2_sample_in_r = fifo_1_2_data_out[17:0];
    wire               i2_sample_out_rdy;
    wire signed [17:0] i2_sample_out_l;
    wire signed [17:0] i2_sample_out_r;
    wire               i2_done;
    wire [91:0]        i2_dsp_ins_flat_l;
    wire [91:0]        i2_dsp_ins_flat_r;
    wire [47:0]        i2_dsp_outs_flat_l = dsp_outs_flat_l;
    wire [47:0]        i2_dsp_outs_flat_r = dsp_outs_flat_r;

    fir_interp_halfband_2x  i2_96k_192k (
        .clk             (clk                   ),
        .reset           (reset                 ),
        .sample_in_rdy   (i2_sample_in_rdy      ),
        .sample_in_l     (i2_sample_in_l        ),
        .sample_in_r     (i2_sample_in_r        ),
        .sample_out_rdy  (i2_sample_out_rdy     ),
        .sample_out_l    (i2_sample_out_l       ),
        .sample_out_r    (i2_sample_out_r       ),
        .done            (i2_done               ),
        .dsp_outs_flat_l (i2_dsp_outs_flat_l    ),
        .dsp_outs_flat_r (i2_dsp_outs_flat_r    ),
        .dsp_ins_flat_l  (i2_dsp_ins_flat_l     ),
        .dsp_ins_flat_r  (i2_dsp_ins_flat_r     )
    );

    wire               i3_sample_in_rdy = fifo_2_3_rd;
    wire signed [17:0] i3_sample_in_l = fifo_2_3_data_out[35:18];
    wire signed [17:0] i3_sample_in_r = fifo_2_3_data_out[17:0];
    wire               i3_sample_out_rdy;
    wire signed [17:0] i3_sample_out_l;
    wire signed [17:0] i3_sample_out_r;
    wire               i3_done;
    wire [91:0]        i3_dsp_ins_flat_l;
    wire [91:0]        i3_dsp_ins_flat_r;
    wire [47:0]        i3_dsp_outs_flat_l = dsp_outs_flat_l;
    wire [47:0]        i3_dsp_outs_flat_r = dsp_outs_flat_r;

    fir_interp_20k_192k_8x  i3_192k_1536k (
        .clk             (clk                   ),
        .reset           (reset                 ),
        .sample_in_rdy   (i3_sample_in_rdy      ),
        .sample_in_l     (i3_sample_in_l        ),
        .sample_in_r     (i3_sample_in_r        ),
        .sample_out_rdy  (i3_sample_out_rdy     ),
        .sample_out_l    (i3_sample_out_l       ),
        .sample_out_r    (i3_sample_out_r       ),
        .done            (i3_done               ),
        .dsp_outs_flat_l (i3_dsp_outs_flat_l    ),
        .dsp_outs_flat_r (i3_dsp_outs_flat_r    ),
        .dsp_ins_flat_l  (i3_dsp_ins_flat_l     ),
        .dsp_ins_flat_r  (i3_dsp_ins_flat_r     )
    );


    // DSP signals interconnection
    wire [91:0] dsp_ins_flat_l = i1_dsp_ins_flat_l | i2_dsp_ins_flat_l |
                                 i3_dsp_ins_flat_l;
    wire [91:0] dsp_ins_flat_r = i1_dsp_ins_flat_r | i2_dsp_ins_flat_r |
                                 i3_dsp_ins_flat_r;
    wire [47:0] dsp_outs_flat_l;
    wire [47:0] dsp_outs_flat_r;

    dsp48a1_inst dsp48a1_l (
        .clk            (clk             ),
        .reset          (reset           ),
        .dsp_ins_flat   (dsp_ins_flat_l  ),
        .dsp_outs_flat  (dsp_outs_flat_l )
    );

    dsp48a1_inst dsp48a1_r (
        .clk            (clk             ),
        .reset          (reset           ),
        .dsp_ins_flat   (dsp_ins_flat_r  ),
        .dsp_outs_flat  (dsp_outs_flat_r )
    );


    // DONE signals gathering
    wire done = i1_done | i2_done | i3_done;


    // SIGMA-DELTA DAC CONTROL
    reg       dac_rd_next_sample;
    reg [6:0] dac_sample_clk_counter;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            dac_rd_next_sample     <= 1'b0;
            dac_sample_clk_counter <= 7'h00;
        end
        else if (dac_sample_clk_counter == `CLK_DIV_1536K-1) begin
            // Skip if there is no data for the DAC
            dac_rd_next_sample     <= fifo_3_dac_empty ? 1'b0 : 1'b1;
            dac_sample_clk_counter <= 7'h00;
        end
        else begin
            dac_rd_next_sample     <= 1'b0;
            dac_sample_clk_counter <= dac_sample_clk_counter + 7'h01;
        end
    end

    wire               dac_sample_in_rdy = dac_rd_next_sample;
    wire signed [17:0] dac_sample_in_l = fifo_3_dac_data_out[35:18];
    wire signed [17:0] dac_sample_in_r = fifo_3_dac_data_out[17:0];

    sigma_delta_2order_dac  sigma_delta_2order_dac_inst
    (
        .clk            (clk                ),
        .reset          (reset              ),
        .sample_in_l    (dac_sample_in_l    ),
        .sample_in_r    (dac_sample_in_r    ),
        .sample_in_rdy  (dac_sample_in_rdy  ),
        .dout_l         (dac_out_l          ),
        .dout_r         (dac_out_r          )
    );


    always @(posedge clk) begin
        if (dac_sample_in_rdy) begin
            $display("%d", dac_out_l);
        end
    end
endmodule
