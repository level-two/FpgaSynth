// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: alu_taylor_coefs_1.v
// Description: Derivatives values of the Taylor series for different
//              functions
// -----------------------------------------------------------------------------

`include "globals.vh"

module alu_taylor_coefs_1 (
    input [2:0]          function_sel,
    input [3:0]          idx,
    output signed [17:0] deriv_coef,
    output signed [17:0] a0
);

    assign deriv_coef = 
        (function_sel == `ALU_TAYLOR_INV_1_PLUS_X) ? deriv_coef_inv_1_plus_x :
        18'h00000;
    assign a0 =
        (function_sel == `ALU_TAYLOR_INV_1_PLUS_X) ? a0_inv_1_plus_x :
        18'h00000;

    wire a0_inv_1_plus_x = 18'h10000;
    reg signed [17:0] deriv_coef_inv_1_plus_x;
    always @(idx) begin
        case (idx)
            4'h0   : begin deriv_coef_inv_1_plus_x <= 18'h08000; end
            4'h1   : begin deriv_coef_inv_1_plus_x <= 18'h38000; end
            4'h2   : begin deriv_coef_inv_1_plus_x <= 18'h38000; end
            4'h3   : begin deriv_coef_inv_1_plus_x <= 18'h38000; end
            4'h4   : begin deriv_coef_inv_1_plus_x <= 18'h38000; end
            4'h5   : begin deriv_coef_inv_1_plus_x <= 18'h38000; end
            4'h6   : begin deriv_coef_inv_1_plus_x <= 18'h38000; end
            4'h7   : begin deriv_coef_inv_1_plus_x <= 18'h38000; end
            4'h8   : begin deriv_coef_inv_1_plus_x <= 18'h38000; end
            4'h9   : begin deriv_coef_inv_1_plus_x <= 18'h38000; end
            4'ha   : begin deriv_coef_inv_1_plus_x <= 18'h38000; end
            default: begin deriv_coef_inv_1_plus_x <= 18'h00000; end
        endcase
    end
endmodule
