module tb_gen_pulse_reg();
    parameter ADDR_WIDTH = 16;
    parameter DATA_WIDTH = 32;

    reg reset;
    reg clk;

    // dut ins
    reg [ADDR_WIDTH-1:0] wbs_address;
    reg [DATA_WIDTH-1:0] wbs_writedata;
    reg wbs_strobe;
    reg wbs_cycle;
    reg wbs_write;

    // dut outs
    wire wbs_ack;
    wire [DATA_WIDTH-1:0] wbs_readdata;


    // registers outs
    wire [31:0] reg_0;

    wire [3:0]  reg_1_field_0;
    wire [2:0]  reg_1_field_1;
    wire [0:0]  reg_1_field_2;
    wire [7:0]  reg_1_field_3;



    reg  [7:0]  reg_2_field_0;
    reg  [7:0]  reg_2_field_1;
    reg  [7:0]  reg_2_field_2;
    reg  [7:0]  reg_2_field_3;


    // dut
    gen_pulse_reg dut(
        .reset(reset),
        .clk(clk),

        // Wishbone signals
        .wbs_address(wbs_address),
        .wbs_writedata(wbs_writedata),
        .wbs_readdata(wbs_readdata),
        .wbs_strobe(wbs_strobe),
        .wbs_cycle(wbs_cycle),
        .wbs_write(wbs_write),
        .wbs_ack(wbs_ack),

        .reg_0(reg_0),
        .reg_1_field_0(reg_1_field_0),
        .reg_1_field_1(reg_1_field_1),
        .reg_1_field_2(reg_1_field_2),
        .reg_1_field_3(reg_1_field_3),

        .reg_2_field_0(reg_2_field_0),
        .reg_2_field_1(reg_2_field_1),
        .reg_2_field_2(reg_2_field_2),
        .reg_2_field_3(reg_2_field_3)
    );

    always begin
        #1;
        clk <= ~clk;
    end


    parameter NREGS = 4;
    reg [ADDR_WIDTH-1:0] addr;
    reg wr;

    initial begin
            clk           <= 0;
            reset         <= 1;
            wbs_address   <= 0;
            wbs_writedata <= 0;
            wbs_strobe    <= 0;
            wbs_cycle     <= 0;
            wbs_write     <= 0;

            addr          <= 0;
            wr            <= 0;

            reg_2_field_0 <= $random();
            reg_2_field_1 <= $random();
            reg_2_field_2 <= $random();
            reg_2_field_3 <= $random();

        repeat (100) @(posedge clk);
            reset <= 0;

        repeat (100) @(posedge clk);

        repeat (10) begin
            addr <= 0;
            repeat (NREGS) begin
                @(posedge clk);
                wbs_address   <= addr;
                wbs_writedata <= $random();
                wbs_write     <= wr;
                wbs_strobe    <= 1;
                wbs_cycle     <= 1;

                while (wbs_ack == 0) @(posedge clk);

                wbs_strobe    <= 0;
                wbs_cycle     <= 0;
                addr          <= addr + 4;
            end
            wr <= ~wr;
        end

        #100;
    end

endmodule
