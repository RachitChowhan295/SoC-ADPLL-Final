`timescale 1ns/1fs

module adpll_top #(
    parameter integer REF_HZ           = 2_000_000,     
    parameter real    DCO_FREE_RUN_HZ  = 70_000_000.0,  // free-running frequency at ctrl_word=0
    parameter real    DCO_KDCO_HZ_LSB  = 400.0           // Hz per LSB of ctrl_word gain
)(
    input wire ref_clk,
    input wire rst,
    input wire[6:0]N_int,
    input wire[6:0]K_mod,
    
    output wire signed [24:0] phase_residual,
    output wire signed [15:0] ctrl_word_out,
    output wire fb_clk,
    output wire [6:0]N_div,
    output wire lock
);

    wire signed [24:0] coarse_error;
    wire signed [7:0] fine_error;
    wire dco_clk;
    wire [6:0] dco_frac_gray; 
    
    wire int_mode = (K_mod == 0)? 1'd1 : 1'd0;

    
    // 1. Counter-Based FLL
    wire fll_locked;
    wire signed [15:0] fll_ctrl;
    
    direct_fll fast_fll_inst (
        .ref_clk(ref_clk),
        .dco_clk(dco_clk),
        .rst(rst),
        .N_int(N_int),     
        .K_mod(K_mod),     
        .fll_ctrl(fll_ctrl),
        .fll_locked(fll_locked)
    );

    
    // 2. Phase Tracking 
    phase_detector pd_inst (
        .ref_clk(ref_clk), 
        .fb_clk(fb_clk), 
        .rst(rst), 
        .phase_error(coarse_error)
    );

    digital_tdc tdc_inst (
        .clk_ref(ref_clk),
        .rst(rst),
        .dco_frac_gray(dco_frac_gray), 
        .tdc_fine_out(fine_error)      
    );

    wire signed [24:0] scaled_coarse = coarse_error <<< 7;
    wire signed [24:0] total_combined_error = scaled_coarse + fine_error;
    
    wire [4:0] dtc_code; 
    wire signed [24:0]phase_residual_dtc;
    wire [6:0] m1_reg;
    wire c2_prev;

    dtc_model dtc_inst_mod (
        .clk(ref_clk),
        .rst(rst),
        .en(~int_mode),
        .phase_error(total_combined_error), 
        .m1_reg(m1_reg),
        .c2_prev(c2_prev),
        .phase_residual(phase_residual_dtc),    
        .dtc_code(dtc_code)
    );

    assign phase_residual = (int_mode)? total_combined_error : phase_residual_dtc;
    
    wire do_update;
    wire signed [24:0] current_phi_error; 

    cic_decimator cic_inst(
        .clk(ref_clk),              
        .rst(rst),               
        .phase_residual(phase_residual), 
        .do_update(do_update),      
        .current_phi_error(current_phi_error),
        .locked(lock)
    );

    wire [4:0] current_kp_shift;
    wire [4:0] current_ki_shift;

    // gain scheduler reinstated for multi-channel dynamic tuning
    gain_scheduler #(
        .ERR_W(25),
        .SHIFT_W(5)
    ) scheduler_inst (
        .clk(ref_clk),                   
        .rst(rst),
        .phase_error(current_phi_error[24:0]),
        .enable(do_update),    
        .kp_shift_sel(current_kp_shift),
        .ki_shift_sel(current_ki_shift)
    );

    wire signed [15:0] pll_ctrl;
    wire pll_enable = do_update & fll_locked;

    // filter accepts dynamic shifts again, retaining the 20-bit ACCUM_W optimization
    pi_loop_filter #(
        .ERR_W(25),
        .SHIFT_W(5),
        .ACCUM_W(20) 
    ) filter_inst (
        .clk(ref_clk),                   
        .rst(rst),
        .enable(pll_enable),              
        .error(current_phi_error[24:0]),       
        .kp_shift(current_kp_shift),
        .ki_shift(current_ki_shift),
        .ctrl_word(pll_ctrl)
    );
    

    // 1. 17 bit wire to capture the sum without overflowing
    wire signed [16:0] sum_ctrl = $signed(fll_ctrl) + $signed(pll_ctrl);
    
    // 2. clamp the result to 16 bits
    wire signed [15:0] final_ctrl_word;
    assign final_ctrl_word = (!fll_locked) ? fll_ctrl :
                             (sum_ctrl > 32767)  ? 16'sd32767 :
                             (sum_ctrl < -32767) ? -16'sd32767 :
                             sum_ctrl[15:0];
                             
    assign ctrl_word_out = final_ctrl_word;
    wire signed [15:0] inverted_ctrl_word = -final_ctrl_word;
    

    dco #(
        .FREE_RUN_HZ(DCO_FREE_RUN_HZ),
        .KDCO_HZ_PER_LSB(DCO_KDCO_HZ_LSB)
    ) inst(
        .rst(rst),
        .ctrl_word(inverted_ctrl_word),
        .dco_clk(dco_clk),
        .dco_frac_gray(dco_frac_gray) 
    );
    
    wire [6:0]N_div_mash;
    
    mash_modulator mash_inst(
        .K_mod(K_mod), 
        .N_int(N_int), 
        .clk(ref_clk), 
        .rst(rst), 
        .en(~int_mode),
        .N_div(N_div_mash), 
        .m1_reg(m1_reg),
        .c2_prev(c2_prev)
    );

    assign N_div = (int_mode)? N_int: N_div_mash;

    clock_devider clkd_inst(
        .N_div(N_div),
        .dco_clk(dco_clk),
        .rst(rst),
        .fb_clk(fb_clk)
    );
endmodule
