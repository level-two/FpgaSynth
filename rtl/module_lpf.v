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

    output reg                  sample_out_rdy,
    output reg signed [17:0]    sample_out,
    output reg                  err_overflow
);


//--------------------------------------------------------
// -------====== State Machine ======-------
//-----------------------------------------------------
    localparam ST_IDLE           = 0;
    localparam ST_CALC_SAMPLE    = 1;
    localparam ST_CALC_COEFS     = 2;
    localparam ST_DONE           = 3;

    reg [1:0] state;
    reg [1:0] next_state;

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            state <= ST_IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            ST_IDLE:        if (sample_in_rdy     ) next_state = ST_CALC_SAMPLE;
            ST_CALC_SAMPLE: if (iir_sample_out_rdy) next_state = lpf_params_changed ? ST_CALC_SAMPLE : ST_DONE;
            ST_CALC_COEFS:  if (coef_calc_done    ) next_state = ST_DONE;
            ST_DONE:                                next_state = ST_IDLE;
        endcase
    end


//-----------------------------------------------------------------------------
// -------====== Connectionn between DSP and calculation modules ======-------
//-------------------------------------------------------------------------
    // Utilize same DSP from several modules
    
    // DSP owner selection
    localparam DSP_OWNER_COEF_CALC  = 0;
    localparam DSP_OWNER_IIR        = 1;

    reg  [1:0]  dsp_owner;
    always @(state) begin
        dsp_owner = DSP_OWNER_COEF_CALC;
        case (state)
            ST_IDLE:        begin end
            ST_CALC_SAMPLE: begin dsp_owner = DSP_OWNER_IIR; end
            ST_CALC_COEFS:  begin dsp_owner = DSP_OWNER_COEF_CALC; end
            ST_DONE:        begin end
        endcase
    end

    // DSP signals interconnection
    wire [83:0] dsp_outs_flat;
    wire [43:0] dsp_ins_flat_coef_calc;
    wire [43:0] dsp_ins_flat_iir;
    wire [43:0] dsp_ins_flat =
        (owner == DSP_OWNER_TAYLOR) ?  dsp_ins_flat_coef_calc :
        (owner == DSP_OWNER_IIR   ) ?  dsp_ins_flat_iir       :
        44'h0;


//-------------------------------------------------
// -------====== Coefs ======-------
//------------------------------------------
    reg [89:0] iir_coefs_flat;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            iir_coefs_flat <= 90'h0;
        end
        else if (coefs_calc_done) begin
            iir_coefs_flat <= coefs_flat_calc;
        end
    end


//-----------------------------------------------------
// -------====== Subblocks instances ======-------
//------------------------------------------
    // IIR filter
    wire signed [17:0]    iir_sample_in     = sample_in;
    wire                  iir_sample_in_rdy = sample_in_rdy;

    wire signed [17:0]    iir_sample_out;
    wire                  iir_sample_out_rdy;

    alu_filter_iir alu_filter_iir (
        .clk             (clk                     ),
        .reset           (reset                   ),
        .sample_in_rdy   (iir_sample_in_rdy       ),
        .sample_in       (iir_sample_in           ),
        .coefs_flat      (iir_coefs_flat          ),
        .sample_out_rdy  (iir_sample_out_rdy      ),
        .sample_out      (iir_sample_out          ),
        .dsp_ins_flat    (iir_dsp_ins_flat_iir    ),
        .dsp_outs_flat   (dsp_outs_flat           )
    );

    assign sample_out     = iir_sample_out;
    assign sample_out_rdy = iir_sample_out_rdy;

    // Coefficients calculator
    reg signed [17:0] coef_calc_omega0;
    reg signed [17:0] coef_calc_inv_2Q;
    wire              coef_calc_do_calc;
    wire [18*5-1:0]   coef_calc_coefs_flat;
    wire              coef_calc_done;

    mudule_lpf_coefs_calc mudule_lpf_coefs_calc (
        .clk            (clk                    ),
        .reset          (reset                  ),
        .omega0         (coef_calc_omega0       ),
        .inv_2Q         (coef_calc_inv_2Q       ),
        .do_calc        (coef_calc_do_calc      ),
        .coefs_flat     (coef_calc_coefs_flat   ),
        .calc_done      (coef_calc_done         ),

        .dsp_outs_flat  (dsp_outs_flat          ),
        .dsp_ins_flat   (dsp_ins_flat_coef_calc )
    );


    // DSP
    dsp48a1_inst dsp48a1_inst (
        .clk            (clk          ),
        .reset          (reset        ),
        .dsp_ins_flat   (dsp_ins_flat ),
        .dsp_outs_flat  (dsp_outs_flat)
    );


//-----------------------------------------------------------
// -------====== Overflow error detection ======-------
//----------------------------------------------
    // When overflow occured, ie multiplication result is >= 2.0 or
    // <= -2.0, higher bits will not be equal
    wire err_overflow_m = m[35] ^ m[34];
    wire err_overflow_p = (&p[47:34]) ^ (|p[47:34]); // 0000 or 0010; 1111 or 1101

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            err_overflow <= 1'b0;
        end
        else if (state == ST_IDLE) begin
            err_overflow <= 1'b0;
        end
        else begin
            err_overflow <= err_overflow | err_overflow_m | err_overflow_p;
        end
    end


//-------------------------------------------
// -------====== Result ======-------
//------------------------------
assign sample_out_rdy = iir_sample_out_rdy;
assign sample_out     = iir_sample_out;


//-----------------------------------------------------------------
// -------====== MIDI Events processing ======-------
//-------------------------------------------------------------

//TODO set lpf_params_changed

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
