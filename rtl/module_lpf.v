// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: module_lpf.v
// Description: LPF implementation based on IIR scheme and Xilinx DSP48A1
// -----------------------------------------------------------------------------

`include "globals.vh"

module module_lpf (
    input                       clk,
    input                       reset,

    input                       midi_rdy,
    input  [`MIDI_CMD_SIZE-1:0] midi_cmd,
    input  [3:0]                midi_ch_sysn,
    input  [6:0]                midi_data0,
    input  [6:0]                midi_data1,

    input                       sample_in_rdy,
    input  signed [17:0]        sample_in,

    output                      sample_out_rdy,
    output signed [17:0]        sample_out
);


    // DSP signals from this module
    reg [1:0]   opmode_x_in;
    reg [1:0]   opmode_z_in;
    reg         opmode_use_preadd;
    reg         opmode_cryin;
    reg         opmode_preadd_sub;
    reg         opmode_postadd_sub;
    reg  signed [17:0] a;
    reg  signed [17:0] b;
    wire signed [35:0] m;
    wire signed [47:0] p;


    // Connectionn between DSP and calculation modules 
    // (utilize same DSP from several modules)
    // DSP owner selection
    localparam DSP_OWNER_LOCAL  = 0;
    localparam DSP_OWNER_TAYLOR = 1;
    localparam DSP_OWNER_IIR    = 2;

    reg  [1:0]  dsp_owner;
    always @(state) begin
        dsp_owner = DSP_OWNER_LOCAL;
        case (state)
            ST_IDLE:           begin end
            ST_IIR_CALC:       begin dsp_owner = DSP_OWNER_IIR; end
            ST_COS_CALC:       begin dsp_owner = DSP_OWNER_TAYLOR; end
            ST_WAIT_RESULT:    begin end
            ST_DONE:           begin end
        endcase
    end

    // DSP signals interconnection
    wire [43:0] dsp_ins_flat;
    wire [43:0] dsp_ins_flat_local;
    wire [43:0] dsp_ins_flat_taylor;
    wire [43:0] dsp_ins_flat_iir;
    wire [83:0] dsp_outs_flat;

    assign dsp_ins_flat = 
        (owner == DSP_OWNER_LOCAL ) ?  dsp_ins_flat_local  :
        (owner == DSP_OWNER_TAYLOR) ?  dsp_ins_flat_taylor :
        (owner == DSP_OWNER_IIR   ) ?  dsp_ins_flat_iir    :
        44'h0;


    // Gather local DSP signals 
    assign dsp_ins_flat_local[43:0] =
        { opmode_postadd_sub, opmode_preadd_sub,
          opmode_cryin      , opmode_use_preadd,
          opmode_z_in       , opmode_x_in      ,
          ain               , bin               };

    assign { m, p } = dsp_outs_flat;




    reg signed [17:0] coefs[0:4];
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            coefs[0] <= 18'h10000; // should always be 1.0
            coefs[1] <= 18'h3f000;
            coefs[2] <= 18'h01000;
            coefs[3] <= 18'h3f000;
            coefs[4] <= 18'h01000;
        end
    end


    wire [18*5-1:0] coefs_flat;
    genvar i;
    generate
        for (i = 0; i < 5; i=i+1) begin : COEFS_BLK
            assign coefs_flat[18*i +: 18] = coefs[i];
        end
    endgenerate


    alu_filter_iir alu_filter_iir (
        .clk             (clk                 ),
        .reset           (reset               ),
        .sample_in_rdy   (sample_in_rdy       ),
        .sample_in       (sample_in           ),
        .coefs_flat      (coefs_flat          ),
        .sample_out_rdy  (sample_out_rdy      ),
        .sample_out      (sample_out          ),
        .dsp_ins_flat    (dsp_ins_flat_iir    ),
        .dsp_outs_flat   (dsp_outs_flat       )
    );

// -----------------------------------------------------------------------------
    reg                do_calc;
    reg [2:0]          function_sel;
    reg  signed [17:0] x_in;
    wire               calc_done;
    wire signed [17:0] result;

    alu_taylor_calc alu_taylor_calc (
        .clk            (clk                 ),
        .reset          (reset               ),
        .do_calc        (do_calc             ),
        .function_sel   (function_sel        ),
        .x_in           (x_in                ),
        .calc_done      (calc_done           ),
        .result         (result              ),
        .dsp_ins_flat   (dsp_ins_flat_taylor ),
        .dsp_outs_flat  (dsp_outs_flat       )
    );

// -----------------------------------------------------------------------------



    dsp48a1_inst dsp48a1_inst (
        .clk            (clk          ),
        .reset          (reset        ),
        .dsp_ins_flat   (dsp_ins_flat ),
        .dsp_outs_flat  (dsp_outs_flat)
    );






//-----------------------------------------------------------------
// -------====== MIDI Events processing ======-------
//-------------------------------------------------------------
    wire      cc_event = (midi_rdy && midi_cmd == `MIDI_CMD_CC);
    reg [7:0] cc_num;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            cc_num <= 0;
        end
        else if (cc_event) begin
            cc_num <= midi_data0;
        end
    end
endmodule
