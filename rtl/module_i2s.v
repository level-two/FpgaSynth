module module_i2s #(parameter  SAMPLE_WIDTH = 16)
(
    input clk,
    input reset,

    input bclk,
    input lrclk,
    input adcda,
    output reg [SAMPLE_WIDTH-1:0] left_out,
    output reg [SAMPLE_WIDTH-1:0] right_out,
    output reg dataready,

    input [SAMPLE_WIDTH-1:0] left_in,
    input [SAMPLE_WIDTH-1:0] right_in,
    output reg data_sampled,
    output bclk_s,
    output lrclk_s,
    output reg dacda
);

    //========================
    crossdomain_signal bclk_crossdomain (
        .reset        (reset    ),
        .clk_b        (clk      ),
        .sig_domain_a (bclk     ),
        .sig_domain_b (bclk_s   )
    );

    reg bclk_dly;
    always @(posedge clk) begin
        if (reset) begin
            bclk_dly <= 1'b0;
        end
        else begin
            bclk_dly <= bclk_s;
        end
    end

    wire bclk_pe  = ~bclk_dly &  bclk_s;
    wire bclk_ne  =  bclk_dly & ~bclk_s;


    //========================
    crossdomain_signal lrclk_crossdomain (
        .reset        (reset    ),
        .clk_b        (clk      ),
        .sig_domain_a (lrclk    ),
        .sig_domain_b (lrclk_s  )
    );

    reg lrclk_dly;
    always @(posedge clk) begin
        if (reset) begin
            lrclk_dly <= 1'b0;
        end
        else if (bclk_pe) begin
            lrclk_dly <= lrclk_s;
        end
    end

    wire lrclk_ch  = lrclk_dly ^ lrclk_s;


    //========================
    crossdomain_signal adcda_crossdomain (
        .reset        (reset    ),
        .clk_b        (clk      ),
        .sig_domain_a (adcda    ),
        .sig_domain_b (adcda_s  )
    );


    // ==============================================================
    reg  [31:0] shift;
    wire [31:0] shift_w = { shift[30:0], adcda_s };
    always @(posedge clk) begin
        if (reset) begin
            shift <= 32'h0;
        end
        else if (bclk_pe) begin
            shift <= shift_w;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            left_out  <= {SAMPLE_WIDTH{1'b0}};
            right_out <= {SAMPLE_WIDTH{1'b0}};
            dataready <= 1'b0;
        end
        else if (bclk_pe && lrclk_ch) begin
            if (lrclk_dly) begin
                right_out <= shift_w[SAMPLE_WIDTH-1:0];
                dataready <= 1'b1;
            end
            else begin
                left_out  <= shift_w[SAMPLE_WIDTH-1:0];
            end
        end
        else begin
            dataready <= 1'b0;
        end
    end


    // ==============================================================
    reg [SAMPLE_WIDTH-1:0] data_right_reg;
    reg [SAMPLE_WIDTH-1:0] shift_reg;

    always @(posedge clk) begin
        if (reset) begin
            data_sampled   <= 1'b0;
            shift_reg      <= {SAMPLE_WIDTH{1'b0}};
            data_right_reg <= {SAMPLE_WIDTH{1'b0}};
            dacda          <= {SAMPLE_WIDTH{1'b0}};
        end
        else if (bclk_pe && lrclk_ch) begin
            if (lrclk_s == 1'b0) begin
                data_right_reg <= right_in;
                shift_reg      <= left_in;
                data_sampled   <= 1'b1;
            end
            else begin
                shift_reg <= data_right_reg;
            end
        end
        else if (bclk_ne) begin
            shift_reg <= { shift_reg[SAMPLE_WIDTH-2:0], 1'b0 };
            dacda     <= shift_reg[SAMPLE_WIDTH-1];
        end
        else begin
            data_sampled <= 1'b0;
        end
    end
endmodule
