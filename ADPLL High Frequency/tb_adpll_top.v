`timescale 1ns/1fs

module tb_adpll_top();

    parameter real DCO_FREE_RUN_HZ = 3500_000_000.0; 
    parameter real KDCO_HZ_PER_LSB = 20000.0;        
    localparam real REF_HZ = 100_000_000.0;

    // system signals
    reg  ref_clk;
    reg  rst;

    reg  [6:0] N_int;
    reg  [6:0] m1_reg;
    reg  [6:0] F_mod;
    reg  [6:0] K_mod;
    reg        c2_prev;

    wire signed [24:0] phase_residual;
    wire signed [15:0] ctrl_word_out;
    wire fb_clk;  
    wire [6:0] N_div;

    // dut instantiation
    adpll_top #(
        .REF_HZ(100_000_000), 
        .DCO_FREE_RUN_HZ(DCO_FREE_RUN_HZ),
        .DCO_KDCO_HZ_LSB(KDCO_HZ_PER_LSB)
    ) dut (
        .ref_clk(ref_clk),
        .fb_clk(fb_clk),
        .rst(rst),
        .N_int(N_int),
        .K_mod(K_mod),
        .phase_residual(phase_residual),
        .ctrl_word_out(ctrl_word_out),
        .N_div(N_div)
    );

    // clock generation
    initial begin
        ref_clk = 1'b0;
        forever #5 ref_clk = ~ref_clk; 
    end
    
    real measured_freq_mhz = 0.0;
    realtime last_edge = 0.0;

    always @(posedge dut.dco_clk) begin
        if (last_edge > 0.0) begin
            measured_freq_mhz = 1000.0 / ($realtime - last_edge);
        end
        last_edge = $realtime;
    end

    // telemetry printout
    integer cycle_count = 0;
    always @(posedge ref_clk) begin
        if (!rst) cycle_count = cycle_count + 1;
        
        if (cycle_count % 500 == 0 && cycle_count > 0) begin
            $display("Ref cycle %0d | Measured Freq: %0.3f MHz | Phase Error: %0d | Ctrl Word: %0d", 
                     cycle_count, measured_freq_mhz, phase_residual, ctrl_word_out);
        end
    end

    // stimulus and run
    real target_freq_mhz;

    initial begin
        $dumpfile("adpll_top.vcd");
        $dumpvars(0, tb_adpll_top);

        $display("==================================================");
        $display(" FULL SYSTEM INTEGRATION TEST                     ");
        $display("==================================================");

        N_int = 7'd32;
        F_mod = 7'd100;
        K_mod = 7'd10;
        target_freq_mhz = (REF_HZ * (N_int + (K_mod / 100.0))) / 1.0e6;
        $display("N_int=%0d K_mod=%0d -> target f = %0.4f MHz", N_int, K_mod, target_freq_mhz);

        #1;
        rst = 1'b1;
        #25;
        rst = 1'b0;
        #1000000; 

        $display("==================================================");
        $display("► Full Simulation Complete.");        
        $finish;
    end

endmodule
