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
    output bclk_s,
    output lrclk_s,
    output dacda
);

    // ==============================================================
    reg [2:0] bclk_trg;
    always @(posedge clk) begin
        if (reset) begin
            bclk_trg <= 3'h0;
        end
        else begin
            bclk_trg <= { bclk_trg[1:0], bclk };
        end
    end

    assign bclk_s = bclk_trg[1];
    wire bclk_pe  = ~bclk_trg[2] &  bclk_trg[1];
    wire bclk_ne  =  bclk_trg[2] & ~bclk_trg[1];

    reg [2:0] lrclk_trg;
    always @(posedge clk) begin
        if (reset) begin
            lrclk_trg <= 3'h0;
        end
        else begin
            lrclk_trg <= { lrclk_trg[1:0], lrclk };
        end
    end

    assign lrclk_s = lrclk_trg[1];
    wire lrclk_prv = lrclk_trg[2];
    wire lrclk_ch  = lrclk_prv ^ lrclk_s;

    reg [1:0] adcda_trg;
    always @(posedge clk) begin
        if (reset) begin
            adcda_trg <= 2'h0;
        end
        else begin
            adcda_trg <= { adcda_trg[0], adcda };
        end
    end

    wire adcda_s = adcda_trg[1];

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
        else if (lrclk_ch) begin
            if (lrclk_prv) begin
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

    /*
    reg [SAMPLE_WIDTH-1:0] lb;
    reg [SAMPLE_WIDTH-1:0] rb;
    reg [4:0] bit_cnt;
    reg actuallr;

    wire [4:0] bit_ptr = (~bit_cnt - (32-SAMPLE_WIDTH));
    assign dacda = (bit_cnt < SAMPLE_WIDTH) ? actuallr ? lb[bit_ptr] : rb[bit_ptr] : 1'b0;

    always @(posedge clk) begin
        if (reset) begin
            bit_cnt  <= 5'h0;
            actuallr <= 1'b0;
            lb       <= {SAMPLE_WIDTH{1'b0}};
            rb       <= {SAMPLE_WIDTH{1'b0}};
        end
        else if (lrclk_ch) begin
            bit_cnt  <= 5'd31;
            actuallr <= ~lrclk_s;
        end
        else if (bclk_ne) begin
            bit_cnt  <= bit_cnt + 1'b1;
            actuallr <= lrclk_s;
            if (bit_cnt == 5'd31) begin
                lb   <= left_in;
                rb   <= right_in;
            end
        end
    end
    */
endmodule
