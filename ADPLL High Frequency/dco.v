`timescale 1ns / 1fs

module dco #(
    parameter real    FREE_RUN_HZ     = 70_000_000.0,  // f0 at ctrl_word = 0
    parameter real    KDCO_HZ_PER_LSB = 400.0,          // DCO gain 
    parameter integer FRAC_BITS       = 7,               
    parameter real    MIN_HZ          = 1_000_000.0      
)(
    input  wire                 rst,
    input  wire signed [15:0]   ctrl_word,
    output reg                  dco_clk,
    output reg  [FRAC_BITS-1:0] dco_frac_gray
);

    localparam integer OVERSAMPLE = (1 << FRAC_BITS);

    
    real period_ns;
    real last_rise_time;

    
    // 1. Main oscillator
    initial begin
        dco_clk        = 1'b0;
        period_ns       = 1.0e9 / FREE_RUN_HZ;
        last_rise_time  = 0.0;
    end

    real f_inst;

    always begin
        if (rst) begin
            dco_clk   = 1'b0;
            period_ns = 1.0e9 / FREE_RUN_HZ;
            @(negedge rst);
        end else begin
            f_inst = FREE_RUN_HZ + KDCO_HZ_PER_LSB * ctrl_word;
            if (f_inst < MIN_HZ) f_inst = MIN_HZ;
            period_ns = 1.0e9 / f_inst;

            #(period_ns / 2.0);
            dco_clk = ~dco_clk;
            if (dco_clk) last_rise_time = $realtime;
        end
    end

    
    // 2. Fine-phase tracker 
    real    frac_real;
    integer frac_idx;
    reg [FRAC_BITS-1:0] frac_bin;

    initial dco_frac_gray = {FRAC_BITS{1'b0}};

    always begin
        if (rst) begin
            dco_frac_gray = {FRAC_BITS{1'b0}};
            @(negedge rst);
        end else begin
            #(period_ns / OVERSAMPLE);

            frac_real = (period_ns > 0.0) ? (($realtime - last_rise_time) / period_ns) : 0.0;
            if (frac_real >= 1.0) frac_real = 0.999999;
            if (frac_real < 0.0)  frac_real = 0.0;

            frac_idx = frac_real * OVERSAMPLE;
            if (frac_idx >= OVERSAMPLE) frac_idx = OVERSAMPLE - 1;

            frac_bin      = frac_idx[FRAC_BITS-1:0];
            dco_frac_gray = frac_bin ^ (frac_bin >> 1);   // binary to gray
        end
    end

endmodule
