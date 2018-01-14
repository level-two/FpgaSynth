// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: crossdomain_data.v
// Description: Block for crossing data from one clk domain to another
// -----------------------------------------------------------------------------


module crossdomain_data #(parameter DATA_WIDTH = 32)
(
    input         reset,
    input         clk_a,
    input [DATA_WIDTH-1:0] data_a,
    input         data_stb_a,
    output        done_a,

    input         clk_b,
    output [DATA_WIDTH-1:0] data_b,
    output        data_stb_b
);


/*
    crossdomain_flag_busy crossdomain_flag_busy (
        .reset(reset),
        .clk_a(clk_a),
        .flag_domain_a(data_stb_a),
        .busy_a(busy_a),

        .clk_b(clk_b),
        .flag_domain_b(data_stb_b)
    );
*/
    crossdomain_flag crossdomain_flag_ab (
        .reset(reset),
        .clk_a(clk_a),
        .clk_b(clk_b),
        .flag_domain_a(data_stb_a),
        .flag_domain_b(data_stb_b)
    );

    crossdomain_flag crossdomain_flag_ba (
        .reset(reset),
        .clk_a(clk_b),
        .clk_b(clk_a),
        .flag_domain_a(data_stb_b),
        .flag_domain_b(done_a)
    );


    reg [DATA_WIDTH-1:0] reg_data[0:1];
    always @(posedge reset or posedge clk_b) begin
        if (reset) begin
            reg_data[0] <= {DATA_WIDTH{1'b0}};
            reg_data[1] <= {DATA_WIDTH{1'b0}};
        end
        else begin
            reg_data[0] <= data_a;
            reg_data[1] <= reg_data[0];
        end
    end

    assign data_b = reg_data[1];

endmodule
