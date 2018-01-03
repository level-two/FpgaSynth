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
    input                        clk           ,
    input                        reset         ,
                                 
    input                        midi_rdy      ,
    input  [`MIDI_CMD_SIZE-1:0]  midi_cmd      ,
    input  [3:0]                 midi_ch_sysn  ,
    input  [6:0]                 midi_data0    ,
    input  [6:0]                 midi_data1    ,
                                 
    input      signed [17:0]     smp_in_l      ,
    input      signed [17:0]     smp_in_r      ,
    input                        smp_in_rdy    ,
    output     signed [17:0]     smp_out_l     ,
    output     signed [17:0]     smp_out_r     ,
    output                       smp_out_rdy   ,
                                 
    output                       err_overflow  ,

    // DSP
    output            [ 7:0]     dsp_hp_op     ,
    output     signed [17:0]     dsp_hp_al     ,
    output     signed [17:0]     dsp_hp_bl     ,
    output     signed [47:0]     dsp_hp_cl     ,
    input      signed [47:0]     dsp_hp_pl     ,
    output     signed [17:0]     dsp_hp_ar     ,
    output     signed [17:0]     dsp_hp_br     ,
    output     signed [47:0]     dsp_hp_cr     ,
    input      signed [47:0]     dsp_hp_pr     ,
    output                       dsp_hp_req    ,
    input                        dsp_hp_gnt    ,

    output            [ 7:0]     dsp_lp_op     ,
    output     signed [17:0]     dsp_lp_al     ,
    output     signed [17:0]     dsp_lp_bl     ,
    output     signed [47:0]     dsp_lp_cl     ,
    input      signed [47:0]     dsp_lp_pl     ,
    output     signed [17:0]     dsp_lp_ar     ,
    output     signed [17:0]     dsp_lp_br     ,
    output     signed [47:0]     dsp_lp_cr     ,
    input      signed [47:0]     dsp_lp_pr     ,
    output                       dsp_lp_req    ,
    input                        dsp_lp_gnt
);


//--------------------------------------------------------
// -------====== State Machine ======-------
//-----------------------------------------------------
    localparam ST_IDLE           = 'h0;
    localparam ST_CALC_SAMPLE    = 'h1;
    localparam ST_CALC_COEFS     = 'h2;
    localparam ST_DONE           = 'h3;

    reg [2:0] state;
    reg [2:0] next_state;

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
            ST_IDLE:        if (smp_in_rdy     ) next_state = ST_CALC_SAMPLE;
            ST_CALC_SAMPLE: if (iir_smp_out_rdy) next_state = lpf_params_changed ? ST_CALC_COEFS : ST_DONE;
            ST_CALC_COEFS : if (coefs_calc_done) next_state = ST_DONE;
            ST_DONE:                             next_state = ST_IDLE;
        endcase
    end


//---------------------------------------
// -------====== DSP ======-------
//--------------------------
    /*
    dsp_nic #(.CLIENTS_N(2)) dsp_nic_lp
    (
        .clk                (clk                    ),
        .reset              (reset                  ),
        .client_op          (client_op              ),
        .client_al          (client_al              ),
        .client_bl          (client_bl              ),
        .client_cl          (client_cl              ),
        .client_pl          (client_pl              ),
        .client_ar          (client_ar              ),
        .client_br          (client_br              ),
        .client_cr          (client_cr              ),
        .client_pr          (client_pr              ),
        .client_req         (client_req             ),
        .client_gnt         (client_gnt             ),
        .dsp_op             (dsp_op                 ),
        .dsp_al             (dsp_al                 ),
        .dsp_bl             (dsp_bl                 ),
        .dsp_cl             (dsp_cl                 ),
        .dsp_pl             (dsp_pl                 ),
        .dsp_ar             (dsp_ar                 ),
        .dsp_br             (dsp_br                 ),
        .dsp_cr             (dsp_cr                 ),
        .dsp_pr             (dsp_pr                 ),
        .dsp_req            (dsp_req                ),
        .dsp_gnt            (dsp_gnt                )
    );
    */



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
    wire signed [17:0]    iir_smp_in     = smp_in;
    wire                  iir_smp_in_rdy = smp_in_rdy;

    wire signed [17:0]    iir_smp_out;
    wire                  iir_smp_out_rdy;

    alu_filter_iir alu_filter_iir (
        .clk             (clk                     ),
        .reset           (reset                   ),
        .smp_in_l        (iir_smp_in_l            ),
        .smp_in_r        (iir_smp_in_r            ),
        .smp_in_rdy      (iir_smp_in_rdy          ),
        .coefs_flat      (iir_coefs_flat          ),
        .smp_out_l       (iir_smp_out_l           ),
        .smp_out_r       (iir_smp_out_r           ),
        .smp_out_rdy     (iir_smp_out_rdy         ),

        .dsp_op          (dsp_hp_op               ),
        .dsp_al          (dsp_hp_al               ),
        .dsp_bl          (dsp_hp_bl               ),
        .dsp_cl          (dsp_hp_cl               ),
        .dsp_pl          (dsp_hp_pl               ),
        .dsp_ar          (dsp_hp_ar               ),
        .dsp_br          (dsp_hp_br               ),
        .dsp_cr          (dsp_hp_cr               ),
        .dsp_pr          (dsp_hp_pr               ),
        .dsp_req         (dsp_hp_req              ),
        .dsp_gnt         (dsp_hp_gnt              )
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
        .clk             (clk                     ),
        .reset           (reset                   ),
        .omega0          (lpf_params_omega0       ),
        .inv_2q          (lpf_params_inv_2Q       ),
        .do_calc         (coefs_calc_do_calc      ),
        .coefs_flat      (coefs_calc_coefs_flat   ),
        .calc_done       (coefs_calc_done         ),

        .dsp_op          (dsp_lp_op               ),
        .dsp_al          (dsp_lp_al               ),
        .dsp_bl          (dsp_lp_bl               ),
        .dsp_cl          (dsp_lp_cl               ),
        .dsp_pl          (dsp_lp_pl               ),
        .dsp_ar          (dsp_lp_ar               ),
        .dsp_br          (dsp_lp_br               ),
        .dsp_cr          (dsp_lp_cr               ),
        .dsp_pr          (dsp_lp_pr               ),
        .dsp_req         (dsp_lp_req              ),
        .dsp_gnt         (dsp_lp_gnt              )
    );


//-------------------------------------------
// -------====== Result ======-------
//------------------------------
    assign smp_out_rdy = iir_smp_out_rdy;
    assign smp_out     = iir_smp_out;

    // Overflow error detection
    // When overflow occured, ie multiplication result is >= 2.0 or
    // <= -2.0, higher bits will not be equal

    wire signed [47:0] p;
    assign p = dsp_outs_flat;

    // TODO: Write errors into OneToClear-registers
    assign err_overflow = (&p[47:34]) ^ (|p[47:34]); // 0000 or 0010; 1111 or 1101


//-----------------------------------------------------------------
// -------====== MIDI Events processing ======-------
//-------------------------------------------------------------
    // TODO Get these values from registers
    localparam MIDI_CHANNEL  = 4'h0;
    localparam OMEGA0_CC_NUM = 7'd21;
    localparam INV_2Q_CC_NUM = 7'd22;

    wire cc_event = midi_rdy     == 1'b1         &&
                    midi_cmd     == `MIDI_CMD_CC &&
                    midi_ch_sysn == MIDI_CHANNEL;

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            lpf_params_changed <= 1'b1;
            lpf_params_omega0  <= 18'h01999;
            lpf_params_inv_2Q  <= 18'h08000;
        end
        else if (cc_event && midi_data0 == OMEGA0_CC_NUM) begin
            lpf_params_changed <= 1'b1;
            lpf_params_omega0  <= { 3'h0, midi_data1[6:0], 8'hff };
        end
        else if (cc_event && midi_data0 == INV_2Q_CC_NUM) begin
            lpf_params_changed <= 1'b1;
            lpf_params_inv_2Q  <= { 2'h0, midi_data1[6:0], 9'h1ff };
                /*
            lpf_params_inv_2Q  <= (midi_data1[6:5] == 2'h0) ?
                { 2'h0, 7'h1f          , 9'h1ff } :
                { 2'h0, midi_data1[6:0], 9'h1ff };
                */
        end
        else if (state == ST_CALC_COEFS) begin
            lpf_params_changed <= 1'b0;
        end
    end
endmodule
