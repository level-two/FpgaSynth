// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: alu_taylor_coefs.v
// Description: Derivatives values of the Taylor series for different
//              functions
// -----------------------------------------------------------------------------

`include "globals.vh"

module alu_taylor_coefs (
    input [2:0]          function_sel,
    input [3:0]          idx,
//    output               last_idx,
    output signed [17:0] deriv_coef
);

    assign deriv_coef = 
        (function_sel == `ALU_TAYLOR_SIN) ? deriv_coef_sin :
        (function_sel == `ALU_TAYLOR_COS) ? deriv_coef_cos :
        (function_sel == `ALU_TAYLOR_INV_1_PLUS_X) ? deriv_coef_inv_1_plus_x :
        18'h00000;

    /*
    assign last_idx =
        (function_sel == `ALU_TAYLOR_SIN) ? last_idx_sin :
        (function_sel == `ALU_TAYLOR_COS) ? last_idx_cos :
        18'h00000;
    */


    reg signed [17:0] deriv_coef_sin;
    //wire last_idx_sin = (idx == 4'ha);
    always @(idx) begin
        case (idx)
            4'h0   : begin deriv_coef_sin <= 18'h00000; end
            4'h1   : begin deriv_coef_sin <= 18'h10000; end
            4'h2   : begin deriv_coef_sin <= 18'h00000; end
            4'h3   : begin deriv_coef_sin <= 18'h30000; end
            4'h4   : begin deriv_coef_sin <= 18'h00000; end
            4'h5   : begin deriv_coef_sin <= 18'h10000; end
            4'h6   : begin deriv_coef_sin <= 18'h00000; end
            4'h7   : begin deriv_coef_sin <= 18'h30000; end
            4'h8   : begin deriv_coef_sin <= 18'h00000; end
            4'h9   : begin deriv_coef_sin <= 18'h10000; end
            4'ha   : begin deriv_coef_sin <= 18'h00000; end
            default: begin deriv_coef_sin <= 18'h00000; end
        endcase
    end


    reg signed [17:0] deriv_coef_cos;
    //wire last_idx_cos = (idx == 4'h9);
    always @(idx) begin
        case (idx)
            4'h0   : begin deriv_coef_cos <= 18'h10000; end
            4'h1   : begin deriv_coef_cos <= 18'h00000; end
            4'h2   : begin deriv_coef_cos <= 18'h30000; end
            4'h3   : begin deriv_coef_cos <= 18'h00000; end
            4'h4   : begin deriv_coef_cos <= 18'h10000; end
            4'h5   : begin deriv_coef_cos <= 18'h00000; end
            4'h6   : begin deriv_coef_cos <= 18'h30000; end
            4'h7   : begin deriv_coef_cos <= 18'h00000; end
            4'h8   : begin deriv_coef_cos <= 18'h10000; end
            4'h9   : begin deriv_coef_cos <= 18'h00000; end
            default: begin deriv_coef_cos <= 18'h00000; end
        endcase
    end


    reg signed [17:0] deriv_coef_inv_1_plus_x;
    //wire last_idx_cos = (idx == 4'h9);
    always @(idx) begin
        case (idx)
            4'h0   : begin deriv_coef_inv_1_plus_x <= 18'h10000; end
            4'h1   : begin deriv_coef_inv_1_plus_x <= 18'h00000; end
            4'h2   : begin deriv_coef_inv_1_plus_x <= 18'h30000; end
            4'h3   : begin deriv_coef_inv_1_plus_x <= 18'h00000; end
            4'h4   : begin deriv_coef_inv_1_plus_x <= 18'h10000; end
            4'h5   : begin deriv_coef_inv_1_plus_x <= 18'h00000; end
            4'h6   : begin deriv_coef_inv_1_plus_x <= 18'h30000; end
            4'h7   : begin deriv_coef_inv_1_plus_x <= 18'h00000; end
            4'h8   : begin deriv_coef_inv_1_plus_x <= 18'h10000; end
            4'h9   : begin deriv_coef_inv_1_plus_x <= 18'h00000; end
            default: begin deriv_coef_inv_1_plus_x <= 18'h00000; end
        endcase
    end
endmodule
