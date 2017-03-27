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
    output     signed [17:0]    sample_out,
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
            ST_DONE:                                next_state = ST_IDLE;
        endcase
    end


//---------------------------------------
// -------====== DSP ======-------
//--------------------------
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
    wire [43:0] dsp_ins_flat_coefs_calc;
    wire [43:0] dsp_ins_flat_iir;
    wire [43:0] dsp_ins_flat =
        (dsp_owner == DSP_OWNER_COEF_CALC) ?  dsp_ins_flat_coefs_calc :
        (dsp_owner == DSP_OWNER_IIR      ) ?  dsp_ins_flat_iir        :
        44'h0;

    // DSP instance
    dsp48a1_inst dsp48a1_inst (
        .clk            (clk          ),
        .reset          (reset        ),
        .dsp_ins_flat   (dsp_ins_flat ),
        .dsp_outs_flat  (dsp_outs_flat)
    );


//---------------------------------------------
// -------====== IIR filter ======-------
//-----------------------------------
    reg [89:0] iir_coefs_flat;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            iir_coefs_flat <= 90'h0;
        end
        else if (coefs_calc_done) begin
            iir_coefs_flat <= coefs_calc_coefs_flat;
        end
    end

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
        .dsp_ins_flat    (dsp_ins_flat_iir        ),
        .dsp_outs_flat   (dsp_outs_flat           )
    );


//---------------------------------------------------------
// -------====== Coefficients calculator ======-------
//-----------------------------------------------
    reg signed [17:0] lpf_params_omega0;
    reg signed [17:0] lpf_params_inv_2Q;
    reg               lpf_params_changed;

    wire              coefs_calc_do_calc;
    wire [18*5-1:0]   coefs_calc_coefs_flat;
    wire              coefs_calc_done;

    // coefs_calc_do_calc
    wire   st_calc = (state == ST_CALC_COEFS);
    reg    st_calc_dly;
    assign coefs_calc_do_calc = (st_calc & ~st_calc_dly);

    always @(posedge reset or posedge clk) begin
        if (reset) st_calc_dly <= 1'b0;
        else       st_calc_dly <= st_calc;
    end

    // lpf coefficients calculator instance
    module_lpf_coefs_calc module_lpf_coefs_calc (
        .clk            (clk                    ),
        .reset          (reset                  ),
        .omega0         (lpf_params_omega0      ),
        .inv_2Q         (lpf_params_inv_2Q      ),
        .do_calc        (coefs_calc_do_calc     ),
        .coefs_flat     (coefs_calc_coefs_flat  ),
        .calc_done      (coefs_calc_done        ),
        .dsp_outs_flat  (dsp_outs_flat          ),
        .dsp_ins_flat   (dsp_ins_flat_coefs_calc )
    );



//-------------------------------------------
// -------====== Result ======-------
//------------------------------
    assign sample_out_rdy = iir_sample_out_rdy;
    assign sample_out     = iir_sample_out;

    // Overflow error detection
    // When overflow occured, ie multiplication result is >= 2.0 or
    // <= -2.0, higher bits will not be equal

    wire signed [47:0] p;
    wire signed [35:0] m;
    assign { m, p } = dsp_outs_flat;

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


//-----------------------------------------------------------------
// -------====== MIDI Events processing ======-------
//-------------------------------------------------------------
    // TODO Get these values from registers
    localparam MIDI_CHANNEL  = 4'h0;
    localparam OMEGA0_CC_NUM = 7'h0;
    localparam INV_2Q_CC_NUM = 7'h1;

    wire cc_event = midi_rdy     == 1'b1         &&
                    midi_cmd     == `MIDI_CMD_CC &&
                    midi_ch_sysn == MIDI_CHANNEL;

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            lpf_params_changed <= 1'b0;
            lpf_params_omega0  <= 18'h00000;
            lpf_params_inv_2Q  <= 18'h00000;
        end
        else if (cc_event && midi_data0 == OMEGA0_CC_NUM) begin
            lpf_params_changed <= 1'b0;
            lpf_params_omega0  <= { 3'h0, midi_data0[6:0], 8'h0 };
        end
        else if (cc_event && midi_data0 == INV_2Q_CC_NUM) begin
            lpf_params_changed <= 1'b0;
            lpf_params_inv_2Q  <= { 2'h0, midi_data0[6:0], 9'h0 };
        end
        else if (state == ST_CALC_COEFS) begin
            lpf_params_changed <= 1'b0;
        end
    end
endmodule
