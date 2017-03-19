// -----------------------------------------------------------------------------
// Copyright © 2017 Yauheni Lychkouski. All Rights Reserved
//
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential
// -----------------------------------------------------------------------------
// File: alu_calc_cos.v
// Description: Module for cosine calculation. Algorithm is based on Taylor 
//              series
//
// Matlab model:
//   fac_nums = zeros(1,11);
//   deriv = [0  1  0 -1  0  1  0 -1  0  1  0 -1];
//   for n = 1:10
//       fac_nums(n) = 1/n;
//   end
//   interm_val = 1;
//   sum = deriv(1);
//   x = pi/2;
//   for n = 1:10
//       a1 = interm_val * fac_nums(n);
//       interm_val = a1 * x;
//       sum = sum + interm_val*deriv(n+1);
//   end
// -----------------------------------------------------------------------------


module alu_calc_cos (
    input  signed [17:0] x_in,
    input                do_calc,

    output signed [17:0] cos,
    output               calc_done
);


//--------------------------------------------------------
// -------====== State Machine ======-------
//-----------------------------------------------------
    localparam ST_IDLE           = 0;
    localparam ST_X_MUL_COEF     = 1;
    localparam ST_INTM_MUL_INTM  = 2;
    localparam ST_INTM_MUL_DERIV = 3;
    localparam ST_WAIT_RESULT    = 4;
    localparam ST_DONE           = 5;

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
            ST_IDLE:           if (do_calc )  next_state = ST_X_MUL_COEF;
            ST_X_MUL_COEF:     if (last_idx)  next_state = ST_INTM_MUL_INTM;
            ST_INTM_MUL_INTM:                 next_state = ST_INTM_MUL_DERIV;
            ST_INTM_MUL_DERIV: if (!last_idx) next_state = ST_INTM_MUL_INTM;
                               else           next_state = ST_WAIT_RESULT;
            ST_WAIT_RESULT:    if (wait_done) next_state = ST_DONE;
            ST_DONE:                          next_state = ST_IDLE;
        endcase
    end


//----------------------------------------------------------
// -------====== DSP instance and signals ======-------
//-------------------------------------------------
    reg [1:0]   opmode_x_in;
    reg [1:0]   opmode_z_in;
    reg         opmode_use_preadd;
    reg         opmode_cryin;
    reg         opmode_preadd_sub;
    reg         opmode_postadd_sub;
    wire signed [17:0] a;
    wire signed [17:0] b;
    wire signed [35:0] m;
    wire signed [47:0] p;

    dsp48a1_inst dsp48a1 (
        .opmode_x_in        (opmode_x_in        ),
        .opmode_z_in        (opmode_z_in        ),
        .opmode_use_preadd  (opmode_use_preadd  ),
        .opmode_cryin       (opmode_cryin       ),
        .opmode_preadd_sub  (opmode_preadd_sub  ),
        .opmode_postadd_sub (opmode_postadd_sub ),
        .ain                (a                  ),
        .bin                (b                  ),
        .mout               (m                  ),
        .pout               (p                  )
    );


//-------------------------------------------------------------
// -------====== DSP Operation mode controll ======-------
//---------------------------------------------------------
    always @(state) begin
        opmode_x_in        = DSP_X_IN_ZERO;
        opmode_z_in        = DSP_Z_IN_ZERO;
        opmode_use_preadd  = 1'b0;
        opmode_cryin       = 1'b0;
        opmode_preadd_sub  = 1'b0;
        opmode_postadd_sub = 1'b0;

        case (state)
            ST_IDLE:           begin end
            ST_X_MUL_COEF:     begin end
            ST_INTM_MUL_INTM:  begin
                opmode_x_in = DSP_X_IN_ZERO; // Skip result from multiplier
                opmode_z_in = DSP_Z_IN_POUT;
            end
            ST_INTM_MUL_DERIV: begin
                opmode_x_in = DSP_X_IN_MULT; // Accept result from multiplier
                opmode_z_in = DSP_Z_IN_POUT;
            end
            ST_WAIT_RESULT:    begin end
            ST_DONE:           begin end
        endcase
    end


//-------------------------------------------------
// -------====== X value ======-------
//------------------------------------------
    reg [17:0] x;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            x <= 18'h0;
        end
        else if (state == ST_IDLE && do_calc == 1'b1) begin
            x <= x_in; // store input value for calculation
        end
    end


//---------------------------------------------------------------------
// -------====== Numbers for factorial calculation ======-------
//--------------------------------------------------------
    reg [17:0] frac_coef;
    always @(idx) begin
        case (idx)
            4'h0   : begin frac_coef <= 18'h10000; end // 1
            4'h1   : begin frac_coef <= 18'h08000; end // 1/2
            4'h2   : begin frac_coef <= 18'h05555; end // 1/3
            4'h3   : begin frac_coef <= 18'h04000; end // 1/4
            4'h4   : begin frac_coef <= 18'h03333; end // 1/5
            4'h5   : begin frac_coef <= 18'h02aab; end // 1/6
            4'h6   : begin frac_coef <= 18'h02492; end // 1/7
            4'h7   : begin frac_coef <= 18'h02000; end // 1/8
            4'h8   : begin frac_coef <= 18'h01c72; end // 1/9
            4'h9   : begin frac_coef <= 18'h0199a; end // 1/10
            default: begin frac_coef <= 18'h00000; end
        endcase
    end



//----------------------------------------------------------------------
// -------====== Obtain intermediate value from DSP ======-------
//-------------------------------------------------------
    wire       store_m_trig;
    wire [3:0] store_idx;

    reg        store_m_trig_dly;
    reg  [3:0] store_idx_dly;
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            store_m_trig_dly <= 0;
            store_idx_dly    <= 4'h0;
        end 
        else begin
            store_m_trig_dly <= store_trig;
            store_idx_dly    <= store_idx;
        end
    end

    
    reg signed [17:0] interm_val[10];
    always @(posedge reset or posedge clk) begin
        if (reset) begin
            interm_val[0] = 18'h10000; // need initialize only this element
        end 
        else if (store_m_trig_dly == 1'b1) begin
            interm_val[store_idx_dly] <= m[33:16];
        end
    end



//-----------------------------------------------
// -------====== idx counter ======-------
//-----------------------------------
    reg [3:0] idx;
    wire      last_idx = (idx == 4'h9);
    always @(posedge reset or posedge clk) begin
        if (reset)
            idx <= 0;
        else if (last_idx)
            idx <= 0;
        else if (state == ST_X_MUL_COEF || state == ST_INTM_MUL_DERIV)
            idx <= idx + 1;
        else
            idx <= 0;
    end


//--------------------------------------------------------
// -------====== Wait Result ======-------
//----------------------------------------------------
    reg [1:0] wait_clac_cnt;
    wire      wait_done = (wait_clac_cnt == 2'h1);

    always @(posedge reset or posedge clk) begin
        if (reset) begin
            wait_clac_cnt <= 0;
        end
        else if (state == ST_WAIT_RESULT) begin
            wait_clac_cnt <= wait_clac_cnt + 1;
        end
        else begin
            wait_clac_cnt <= 0;
        end
    end


//---------------------------------------------------
// -------====== Result ======-------
//-----------------------------------------
    assign calc_done = (state == ST_DONE) ? 1'b1     : 1'b0;
    assign cos       = (state == ST_DONE) ? p[33:16] : 18'h0;
endmodule

