`timescale 1ns/1fs

module direct_fll #(
    parameter integer C_WIDTH = 24,       
    parameter integer FLL_GAIN_SHIFT = 4  
)(
    input  wire ref_clk,
    input  wire dco_clk,
    input  wire rst,
    input  wire [6:0] N_int,
    input  wire [6:0] K_mod,
    
    output reg signed [15:0] fll_ctrl,
    output reg fll_locked
);
    localparam [6:0] F_mod = 7'd100;
    localparam integer DIV100_SHIFT = 17;
    localparam integer DIV100_MAGIC = 1311;

    
    // 1. DCO Edge Counter 
    reg [C_WIDTH-1:0] dco_count;
    always @(posedge dco_clk or posedge rst) begin
        if (rst) dco_count <= 0;
        else dco_count <= dco_count + 1;
    end

    
    // 2. cross the fast counter into Ref Clock
    wire [C_WIDTH-1:0] dco_count_gray = dco_count ^ (dco_count >> 1);
    (* ASYNC_REG = "TRUE" *) reg [C_WIDTH-1:0] gray_sync1, gray_sync2;
    
    always @(posedge ref_clk or posedge rst) begin
        if (rst) begin
            gray_sync1 <= 0;
            gray_sync2 <= 0;
        end else begin
            gray_sync1 <= dco_count_gray;
            gray_sync2 <= gray_sync1;
        end
    end

    
    // 3. gray to binary decoder
    reg [C_WIDTH-1:0] bin_sync;
    integer i;
    always @(*) begin
        bin_sync[C_WIDTH-1] = gray_sync2[C_WIDTH-1];
        for (i = C_WIDTH-2; i >= 0; i = i - 1) begin
            bin_sync[i] = bin_sync[i+1] ^ gray_sync2[i];
        end
    end

    
    // 4. time window generator
    reg [3:0] ref_cnt;
    reg [C_WIDTH-1:0] bin_sync_prev;
    reg signed [C_WIDTH-1:0] freq_err; 
    reg update_fll;

    wire [10:0] k_mod_scaled  = K_mod << 4;                                   
    wire [12:0] k_mod_div100  = (k_mod_scaled * DIV100_MAGIC) >> DIV100_SHIFT; 
    
    
    wire [C_WIDTH-1:0] target_16 = (N_int << 4) + k_mod_div100;
    wire [C_WIDTH-1:0] actual_cycles = bin_sync - bin_sync_prev;

    always @(posedge ref_clk or posedge rst) begin
        if (rst) begin
            ref_cnt <= 0;
            bin_sync_prev <= 0;
            update_fll <= 0;
            freq_err <= 0;
        end else begin
            ref_cnt <= ref_cnt + 1;
            update_fll <= (ref_cnt == 4'd15);
            
            if (ref_cnt == 4'd15) begin
                freq_err <= $signed({1'b0, target_16}) - $signed({1'b0, actual_cycles});
                bin_sync_prev <= bin_sync;
            end
        end
    end
    
    // 5. FLL Integrator & Handoff
    reg [2:0] lock_timer; // increased timer to avoid false locks on high frequencies
    
    wire signed [31:0] freq_err_shifted = freq_err <<< FLL_GAIN_SHIFT;
    wire signed [31:0] next_fll_ctrl_wide = $signed({{16{fll_ctrl[15]}}, fll_ctrl}) - freq_err_shifted;

    always @(posedge ref_clk or posedge rst) begin
        if (rst) begin
            fll_ctrl   <= 0;
            fll_locked <= 0;
            lock_timer <= 0;
        end else if (update_fll) begin
            
            if (!fll_locked) begin
                if (next_fll_ctrl_wide > 32767)
                    fll_ctrl <= 16'd32767;
                else if (next_fll_ctrl_wide < -32768)
                    fll_ctrl <= -16'd32768;
                else
                    fll_ctrl <= next_fll_ctrl_wide[15:0];
            end

            if (freq_err >= -4 && freq_err <= 4) begin
                if (lock_timer < 3) lock_timer <= lock_timer + 1;
                else fll_locked <= 1'b1;
            end else begin
                lock_timer <= 0;
            end
        end
    end
endmodule
