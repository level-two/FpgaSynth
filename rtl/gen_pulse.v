// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: gen_pulse.v
// Description: Simple pulse generator
// -----------------------------------------------------------------------------

`include "globals.vh"

module gen_pulse (
    input             clk,
    input             reset,

    input             gen_left_sample,
    input             gen_right_sample,

    input             midi_rdy,
    input  [`MIDI_CMD_SIZE-1:0] midi_cmd,
    input  [3:0]      midi_ch_sysn,
    input  [6:0]      midi_data0,
    input  [6:0]      midi_data1,

    output reg        left_sample_rdy,
    output reg signed [17:0] left_sample_out,

    output reg        right_sample_rdy,
    output reg signed [17:0] right_sample_out
);

    reg [7:0] note;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            note <= 0;
        end
        else if (midi_rdy && midi_cmd == `MIDI_CMD_NOTE_ON) begin
            note <= midi_data0;
        end
    end

    reg [31:0] div;
    always @(note) begin
        case (note)
            7'h00: div <= 32'h03a52528;
            7'h01: div <= 32'h0370c590;
            7'h02: div <= 32'h033f567c;
            7'h03: div <= 32'h0310adac;
            7'h04: div <= 32'h02e4a348;
            7'h05: div <= 32'h02bb11ac;
            7'h06: div <= 32'h0293d550;
            7'h07: div <= 32'h026eccb8;

            7'h08: div <= 32'h024bd838;
            7'h09: div <= 32'h022ad9f8;
            7'h0a: div <= 32'h020bb5c4;
            7'h0b: div <= 32'h01ee5102;
            7'h0c: div <= 32'h01d29294;
            7'h0d: div <= 32'h01b862c8;
            7'h0e: div <= 32'h019fab3e;
            7'h0f: div <= 32'h018856d6;

            7'h10: div <= 32'h017251a4;
            7'h11: div <= 32'h015d88d6;
            7'h12: div <= 32'h0149eaa8;
            7'h13: div <= 32'h0137665c;
            7'h14: div <= 32'h0125ec1c;
            7'h15: div <= 32'h01156cfc;
            7'h16: div <= 32'h0105dae2;
            7'h17: div <= 32'h00f72882;

            7'h18: div <= 32'h00e9494a;
            7'h19: div <= 32'h00dc3166;
            7'h1a: div <= 32'h00cfd59e;
            7'h1b: div <= 32'h00c42b6c;
            7'h1c: div <= 32'h00b928d4;
            7'h1d: div <= 32'h00aec46a;
            7'h1e: div <= 32'h00a4f554;
            7'h1f: div <= 32'h009bb32e;

            7'h20: div <= 32'h0092f60e;
            7'h21: div <= 32'h008ab67e;
            7'h22: div <= 32'h0082ed72;
            7'h23: div <= 32'h007b9440;
            7'h24: div <= 32'h0074a4a5;
            7'h25: div <= 32'h006e18b3;
            7'h26: div <= 32'h0067eacf;
            7'h27: div <= 32'h006215b6;

            7'h28: div <= 32'h005c946a;
            7'h29: div <= 32'h00576235;
            7'h2a: div <= 32'h00527aaa;
            7'h2b: div <= 32'h004dd997;
            7'h2c: div <= 32'h00497b07;
            7'h2d: div <= 32'h00455b3f;
            7'h2e: div <= 32'h004176b9;
            7'h2f: div <= 32'h003dca20;

            7'h30: div <= 32'h003a5253;
            7'h31: div <= 32'h00370c59;
            7'h32: div <= 32'h0033f568;
            7'h33: div <= 32'h00310adb;
            7'h34: div <= 32'h002e4a34;
            7'h35: div <= 32'h002bb11b;
            7'h36: div <= 32'h00293d55;
            7'h37: div <= 32'h0026eccb;

            7'h38: div <= 32'h0024bd84;
            7'h39: div <= 32'h0022ada0;
            7'h3a: div <= 32'h0020bb5c;
            7'h3b: div <= 32'h001ee510;
            7'h3c: div <= 32'h001d2929;
            7'h3d: div <= 32'h001b862c;
            7'h3e: div <= 32'h0019fab4;
            7'h3f: div <= 32'h0018856d;

            7'h40: div <= 32'h0017251a;
            7'h41: div <= 32'h0015d88e;
            7'h42: div <= 32'h00149eab;
            7'h43: div <= 32'h00137666;
            7'h44: div <= 32'h00125ec2;
            7'h45: div <= 32'h001156d0;
            7'h46: div <= 32'h00105dae;
            7'h47: div <= 32'h000f7288;

            7'h48: div <= 32'h000e9495;
            7'h49: div <= 32'h000dc316;
            7'h4a: div <= 32'h000cfd5a;
            7'h4b: div <= 32'h000c42b7;
            7'h4c: div <= 32'h000b928d;
            7'h4d: div <= 32'h000aec47;
            7'h4e: div <= 32'h000a4f55;
            7'h4f: div <= 32'h0009bb33;

            7'h50: div <= 32'h00092f61;
            7'h51: div <= 32'h0008ab68;
            7'h52: div <= 32'h00082ed7;
            7'h53: div <= 32'h0007b944;
            7'h54: div <= 32'h00074a4a;
            7'h55: div <= 32'h0006e18b;
            7'h56: div <= 32'h00067ead;
            7'h57: div <= 32'h0006215b;

            7'h58: div <= 32'h0005c947;
            7'h59: div <= 32'h00057623;
            7'h5a: div <= 32'h000527ab;
            7'h5b: div <= 32'h0004dd99;
            7'h5c: div <= 32'h000497b0;
            7'h5d: div <= 32'h000455b4;
            7'h5e: div <= 32'h0004176c;
            7'h5f: div <= 32'h0003dca2;

            7'h60: div <= 32'h0003a525;
            7'h61: div <= 32'h000370c6;
            7'h62: div <= 32'h00033f56;
            7'h63: div <= 32'h000310ae;
            7'h64: div <= 32'h0002e4a3;
            7'h65: div <= 32'h0002bb12;
            7'h66: div <= 32'h000293d5;
            7'h67: div <= 32'h00026ecd;

            7'h68: div <= 32'h00024bd8;
            7'h69: div <= 32'h00022ada;
            7'h6a: div <= 32'h00020bb6;
            7'h6b: div <= 32'h0001ee51;
            7'h6c: div <= 32'h0001d293;
            7'h6d: div <= 32'h0001b863;
            7'h6e: div <= 32'h00019fab;
            7'h6f: div <= 32'h00018857;

            7'h70: div <= 32'h00017252;
            7'h71: div <= 32'h00015d89;
            7'h72: div <= 32'h000149eb;
            7'h73: div <= 32'h00013766;
            7'h74: div <= 32'h000125ec;
            7'h75: div <= 32'h0001156d;
            7'h76: div <= 32'h000105db;
            7'h77: div <= 32'h0000f728;

            7'h78: div <= 32'h0000e949;
            7'h79: div <= 32'h0000dc31;
            7'h7a: div <= 32'h0000cfd6;
            7'h7b: div <= 32'h0000c42b;
            7'h7c: div <= 32'h0000b929;
            7'h7d: div <= 32'h0000aec4;
            7'h7e: div <= 32'h0000a4f5;
            7'h7f: div <= 32'h00009bb3;
        endcase
    end
    



    reg  [31:0] divider_cnt;
    wire        divider_cnt_evnt = (divider_cnt == 0);
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            divider_cnt <= 0;
        end
        else if (divider_cnt == div) begin
        //else if (divider_cnt == 32'd113_636) begin
            // 440 Hz, when CLK is 100 MHz
            divider_cnt <= 0;
        end
        else begin
            divider_cnt <= divider_cnt + 1;
        end
    end


    reg signed [17:0] sample_val;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            sample_val <= 0;
        end
        else if (midi_rdy && midi_cmd == `MIDI_CMD_NOTE_ON) begin
            sample_val <= {2'b00, midi_data1, 9'b0}; // Q2.16
        end
        else if (midi_rdy && midi_cmd == `MIDI_CMD_NOTE_OFF) begin
            sample_val <= 0;
        end
        else if (divider_cnt_evnt) begin
            sample_val <= -sample_val;
        end
    end

    
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            left_sample_out  <= 0;
            left_sample_rdy  <= 0;
            right_sample_out <= 0;
            right_sample_rdy <= 0;
        end
        else if (gen_left_sample) begin
            left_sample_out  <= sample_val;
            left_sample_rdy  <= 1;
        end
        else if (gen_right_sample) begin
            right_sample_out <= sample_val;
            right_sample_rdy <= 1;
        end
        else begin
            left_sample_rdy  <= 0;
            right_sample_rdy <= 0;
        end
    end
endmodule

