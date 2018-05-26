module wbm_traffic_gen
(
    input                     clk,
    input                     reset,

    input                     enable_traffic_gen,
    output reg                data_mismatch,

    // WISHBONE SLAVE INTERFACE FOR SDRAM ACCESS
    output reg [31:0]         wbm_sdram_address   ,
    output reg [15:0]         wbm_sdram_writedata ,
    input      [15:0]         wbm_sdram_readdata  ,
    output reg                wbm_sdram_strobe    ,
    output reg                wbm_sdram_cycle     ,
    output reg                wbm_sdram_write     ,
    input                     wbm_sdram_ack       ,
    input                     wbm_sdram_stall     
    //input                   wbm_sdram_err       , // TBI
);

    localparam INIT_WAIT = 150_00; // 1ms //150_00; // 150us
    localparam CMDS_N    = 10000;
    localparam WAIT_N    = 1000;


    localparam ST_IDLE         = 'h0;
    localparam ST_SEND_WR      = 'h1;
    localparam ST_SEND_RD      = 'h2;
    localparam ST_WAIT_WR_ACKS = 'h3;
    localparam ST_WAIT_RD_ACKS = 'h4;
    localparam ST_WAIT         = 'h5;
    localparam ST_INIT_WAIT    = 'h6;

    reg [31:0] state;
    reg [31:0] next_state;
    always @(posedge clk or posedge reset) begin
        if (reset) state <= ST_INIT_WAIT;
        else       state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            ST_INIT_WAIT: begin
                if (init_wait_cnt == INIT_WAIT) next_state = ST_IDLE;
            end
            ST_IDLE: begin
                if (enable_traffic_gen) next_state = ST_SEND_WR;
            end
            ST_SEND_WR: begin
                if (sent_num == CMDS_N) next_state = ST_WAIT_WR_ACKS;
            end
            ST_SEND_RD: begin
                if (sent_num == CMDS_N) next_state = ST_WAIT_RD_ACKS;
            end
            ST_WAIT_WR_ACKS: begin
                if (ack_num == CMDS_N) next_state = ST_WAIT;
            end
            ST_WAIT_RD_ACKS: begin
                if (ack_num == CMDS_N) next_state = ST_WAIT;
            end
            ST_WAIT: begin
                next_state = (wait_cnt != WAIT_N) ? ST_WAIT    :
                              next_cmd_rd         ? ST_SEND_RD :
                                                    ST_SEND_WR ;
            end
            default: begin
                next_state = ST_IDLE;
            end
        endcase
    end


    reg [31:0] init_wait_cnt;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            init_wait_cnt <= 0;
        end else if (state == ST_INIT_WAIT) begin
            init_wait_cnt <= init_wait_cnt + 1;
        end else begin
            init_wait_cnt <= 0;
        end
    end


    reg [31:0] wait_cnt;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            wait_cnt <= 0;
        end else if (state == ST_WAIT) begin
            wait_cnt <= wait_cnt + 1;
        end else begin
            wait_cnt <= 0;
        end
    end

    reg next_cmd_rd;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            next_cmd_rd <= 0;
        end else if (next_state != state && next_state == ST_WAIT) begin
            next_cmd_rd <= ~next_cmd_rd;
        end
    end

    reg [31:0] wr_addr;
    reg [31:0] rd_addr;
    reg [31:0] sent_num;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            wr_addr  <= 0;
            rd_addr  <= 0;
            sent_num <= 0;
        end else if (state == ST_IDLE || state == ST_WAIT) begin
            sent_num <= 0;
        end else if (state == ST_SEND_WR && !wbm_sdram_stall) begin
            wr_addr  <= wr_addr+1;
            sent_num <= sent_num + 1;
        end else if (state == ST_SEND_RD && !wbm_sdram_stall) begin
            rd_addr  <= rd_addr+1;
            sent_num <= sent_num + 1;
        end
    end

    reg [31:0] ack_num;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ack_num <= 0;
        end else if (state == ST_IDLE || state == ST_WAIT) begin
            ack_num <= 0;
        end else if (wbm_sdram_ack) begin
            ack_num <= ack_num + 1;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            data_mismatch <= 1'b0;
        end
        else if (state == ST_IDLE) begin
            data_mismatch <= 1'b0;
        end
        else if ((state == ST_SEND_RD || state == ST_WAIT_RD_ACKS) &&
                 wbm_sdram_ack &&
                 wbm_sdram_readdata != ack_num[15:0]) begin
            data_mismatch <= 1'b1;
        end
    end 

    always @(*) begin
        wbm_sdram_address   <= 'h0;
        wbm_sdram_writedata <= 'h0;
        wbm_sdram_strobe    <= 'h0;
        wbm_sdram_cycle     <= 'h0;
        wbm_sdram_write     <= 'h0;

        if (state == ST_SEND_WR) begin
            wbm_sdram_address   <= wr_addr;
            wbm_sdram_writedata <= sent_num[15:0];
            wbm_sdram_strobe    <= 1'b1;
            wbm_sdram_cycle     <= 1'b1;
            wbm_sdram_write     <= 1'b1;
        end
        else if (state == ST_SEND_RD) begin
            wbm_sdram_address   <= rd_addr;
            wbm_sdram_strobe    <= 1'b1;
            wbm_sdram_cycle     <= 1'b1;
            wbm_sdram_write     <= 1'b0;
        end
        else if (state == ST_WAIT_WR_ACKS || state == ST_WAIT_RD_ACKS) begin
            wbm_sdram_cycle     <= 1'b1;
        end
    end 
endmodule
