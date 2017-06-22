// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: tb_fir_decim_384k_48k.v
// Description: Test bench for the decimating 384k->48k filter
// -----------------------------------------------------------------------------

`include "../rtl/globals.vh"

module tb_fir_decim_384k_48k();
    reg                clk;
    reg                reset;

    reg                sample_in_rdy;
    reg  signed [17:0] sample_in_l;
    reg  signed [17:0] sample_in_r;

    wire               sample_out_rdy;
    wire signed [17:0] sample_out_l;
    wire signed [17:0] sample_out_r;

    wire [47:0]        dsp_outs_flat_l;
    wire [47:0]        dsp_outs_flat_r;
    wire [91:0]        dsp_ins_flat_l;
    wire [91:0]        dsp_ins_flat_r;

    // dut
    fir_decim_384k_48k dut (
        .clk              (clk             ),
        .reset            (reset           ),
        .sample_in_rdy    (sample_in_rdy   ),
        .sample_in_l      (sample_in_l     ),
        .sample_in_r      (sample_in_r     ),
        .sample_out_rdy   (sample_out_rdy  ),
        .sample_out_l     (sample_out_l    ),
        .sample_out_r     (sample_out_r    ),
        .dsp_outs_flat_l  (dsp_outs_flat_l ),
        .dsp_outs_flat_r  (dsp_outs_flat_r ),
        .dsp_ins_flat_l   (dsp_ins_flat_l  ),
        .dsp_ins_flat_r   (dsp_ins_flat_r  )
    );

    // DSP instances
    dsp48a1_inst dsp48a1_inst_l (
        .clk            (clk            ),
        .reset          (reset          ),
        .dsp_ins_flat   (dsp_ins_flat_l ),
        .dsp_outs_flat  (dsp_outs_flat_l)
    );
    dsp48a1_inst dsp48a1_inst_r (
        .clk            (clk            ),
        .reset          (reset          ),
        .dsp_ins_flat   (dsp_ins_flat_r ),
        .dsp_outs_flat  (dsp_outs_flat_r)
    );


    initial $timeformat(-9, 0, " ns", 0);

    always begin
        #0.5;
        clk <= ~clk;
    end


    initial begin
            clk             <= 0;
            reset           <= 1;

            sample_in_rdy   <= 0;
            sample_in_l     <= 0;
            sample_in_r     <= 0;

        repeat (100) @(posedge clk);
            reset <= 0;

        repeat (100) @(posedge clk);

        sample_in_l     <= 18'h00000;
        sample_in_r     <= 18'h00000;

        repeat (100) begin
            sample_in_rdy <= 1;
            @(posedge clk);
            sample_in_rdy <= 0;
            repeat (100) @(posedge clk);
        end

        sample_in_l     <= 18'h01000;
        sample_in_r     <= 18'h01000;

        repeat (100) begin
            sample_in_rdy <= 1;

            @(posedge clk);
            sample_in_rdy <= 0;

            //sample_in_l     <= sample_in_l + 18'h00100;
            //sample_in_r     <= sample_in_r + 18'h00100;

            repeat (100) @(posedge clk);
        end

        #100;

        $finish;
    end

    always @(posedge clk) begin
        if (sample_out_rdy) begin
            $display("%d", sample_out_l);
        end
    end

endmodule
