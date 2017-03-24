// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: tb_alu_taylor_calc.v
// Description: Test bench for the alu_calc_result module
// -----------------------------------------------------------------------------

`include "../rtl/globals.vh"

module tb_alu_taylor_calc();
    reg                reset;
    reg                clk;

    reg                do_calc;
    reg [2:0]          function_sel;
    reg  signed [17:0] x_in;
    wire               calc_done;
    wire signed [17:0] result;

    wire [43:0] dsp_ins_flat;
    wire [83:0] dsp_outs_flat;

    // dut
    alu_taylor_calc dut (
        .clk            (clk            ),
        .reset          (reset          ),
        .do_calc        (do_calc        ),
        .function_sel   (function_sel   ),
        .x_in           (x_in           ),
        .calc_done      (calc_done      ),
        .result         (result         ),
        .dsp_ins_flat   (dsp_ins_flat   ),
        .dsp_outs_flat  (dsp_outs_flat  )
    );

    dsp48a1_inst dsp48a1_inst (
        .clk            (clk          ),
        .reset          (reset        ),
        .dsp_ins_flat   (dsp_ins_flat ),
        .dsp_outs_flat  (dsp_outs_flat)
    );



    always begin
        #1;
        clk <= ~clk;
    end


    initial begin
        clk          <= 0;
        reset        <= 1;

        do_calc      <= 0;
        function_sel <= `ALU_TAYLOR_SIN;
        x_in         <= 0;

        repeat (100) @(posedge clk);
        reset <= 0;
        repeat (100) @(posedge clk);

        repeat (10) begin
            do_calc      <= 1;
            function_sel <= `ALU_TAYLOR_SIN;
            x_in         <= 18'h19220;
            @(posedge clk);
            do_calc      <= 0;

            repeat (100) @(posedge clk);

            do_calc      <= 1;
            function_sel <= `ALU_TAYLOR_COS;
            x_in         <= 18'h19220;
            @(posedge clk);
            do_calc      <= 0;

            repeat (100) @(posedge clk);
        end

        #100;
    end
endmodule
