// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: tb_alu_calc_cos.v
// Description: Test bench for the alu_calc_cos module
// -----------------------------------------------------------------------------

`include "../rtl/globals.vh"

module tb_alu_calc_cos();
    reg                reset;
    reg                clk;

    reg  signed [17:0] x_in;
    reg                do_calc;
    wire signed [17:0] cos;
    wire               calc_done;

    // dut
    alu_calc_cos dut(
        .clk        (clk        ),
        .reset      (reset      ),
        .x_in       (x_in       ),
        .do_calc    (do_calc    ),
        .cos        (cos        ),
        .calc_done  (calc_done  )
    );


    always begin
        #1;
        clk <= ~clk;
    end


    initial begin
            clk         <= 0;
            reset       <= 1;

            x_in        <= 0;
            do_calc     <= 0;

        repeat (100) @(posedge clk);
            reset <= 0;

        repeat (100) @(posedge clk);

        repeat (10) begin
            x_in        <= 18'h19220;
            do_calc     <= 1;
            @(posedge clk);
            do_calc     <= 0;
            repeat (100) @(posedge clk);
        end

        #100;
    end

endmodule

