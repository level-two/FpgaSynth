// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: tb_fir_interpolator_2x.v
// Description: Test bench for the interpolating halfband filter
// -----------------------------------------------------------------------------

`include "../rtl/globals.vh"

module tb_fir_interp_halfband_2x();
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
    fir_interp_halfband_2x dut (
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

        repeat (100) begin : SAMPLES
            reg [15:0] val;

            sample_in_rdy   <= 1;
            val = $random();
            sample_in_l     <= {2'b0, val};
            val = $random();
            sample_in_r     <= {2'b0, val};

            @(posedge clk);
            sample_in_rdy <= 0;
            repeat (200) @(posedge clk);
        end

        #100;

        $finish;
    end

endmodule
