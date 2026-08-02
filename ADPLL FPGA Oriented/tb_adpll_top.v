`timescale 1ns/1ps

module tb_adpll_top();

    // system signals
    reg  ref_clk;
    reg  rst;
    reg board_clk;

    reg  [5:0] N_int;
    reg  [6:0] m1_reg;
    reg  [6:0] F_mod;
    reg  [6:0] K_mod;
    reg        c2_prev;

    wire signed [24:0] phase_residual;
    wire signed [15:0] ctrl_word_out;
    wire fb_clk;  

    wire [5:0]N_div;

    // dut instantiation
    adpll_top dut (
        .ref_clk(ref_clk),
        .fb_clk(fb_clk),
        .rst(rst),
        .board_clk(board_clk),
        .N_int(N_int),
        .K_mod(K_mod),
        .phase_residual(phase_residual),
        .ctrl_word_out(ctrl_word_out),
        .N_div(N_div)
    );

    // clock generation
    initial begin
        ref_clk = 1'b0;
        forever #250.0 ref_clk = ~ref_clk; 
    end

    // board clock generation 
    initial begin
        board_clk = 1'b0;
        forever #1.25 board_clk = ~board_clk; 
    end


    
    real ndiv_sum = 0.0;
    integer ndiv_count = 0;
    real ndiv_average;

    always @(posedge ref_clk) begin
        if (!rst) begin
            ndiv_sum = ndiv_sum + N_div;
            ndiv_count = ndiv_count + 1;
        end
    end

    
    task print_ndiv_average;
        begin
            ndiv_average = ndiv_sum / ndiv_count;
            $display("Time=%0t | Samples=%0d | Average N_div = %.6f (ideal = 30.1)",
                    $time, ndiv_count, ndiv_average);
        end
    endtask

    
    real last_edge_time = 0.0;
    real period_sum_ns = 0.0;
    integer period_count = 0;
    real measured_freq_mhz = 0.0;

    parameter AVG_EDGES = 100; 

    always @(posedge dut.dco_clk) begin
        if (!rst) begin
            if (last_edge_time != 0.0) begin
                period_sum_ns = period_sum_ns + ($realtime - last_edge_time);
                period_count = period_count + 1;

                if (period_count == AVG_EDGES) begin
                    measured_freq_mhz = (1000.0 * AVG_EDGES) / period_sum_ns;
                    period_sum_ns = 0.0;
                    period_count = 0;
                end
            end
            last_edge_time = $realtime;
        end
        else begin
            last_edge_time = 0.0;
            period_sum_ns = 0.0;
            period_count = 0;
        end
    end


    
    integer cycle_count = 0;
    always @(posedge ref_clk) begin
        if (!rst) cycle_count = cycle_count + 1;
        
        if (cycle_count % 500 == 0 && cycle_count > 0) begin
            $display("Ref cycle %0d | Measured Freq: %0.3f MHz | Phase Error: %0d | Ctrl Word: %0d", 
                     cycle_count, measured_freq_mhz, phase_residual, ctrl_word_out);
        end
    end

    
    initial begin
        $dumpfile("adpll_top.vcd");
        $dumpvars(0, tb_adpll_top);

        $display("==================================================");
        $display(" FULL SYSTEM INTEGRATION TEST                     ");
        $display("==================================================");

        N_int = 6'd30;
        F_mod = 7'd100;
        K_mod = 7'd10;
        #1;
        rst = 1'b1;
        #25;
        rst = 1'b0;
        #15000000; 

        $display("==================================================");
        $display("► Full Simulation Complete.");
        $finish;
    end

endmodule
