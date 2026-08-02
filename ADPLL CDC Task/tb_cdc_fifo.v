`timescale 1ns/1ps

module tb_cdc_fifo();

    reg  ref_clk;
    reg  clk_fast; 
    reg  rst;
    reg  [6:0] N_int = 7'd35; 
    reg  [6:0] K_mod = 7'd0;

    // FIFO interface
    reg         fifo_wr_en;
    reg  [15:0] fifo_data_in;
    wire        fifo_full;
    reg         fifo_rd_en;
    wire [15:0] fifo_data_out;
    wire        fifo_empty;
    
    
    wire signed [24:0] phase_residual;
    wire signed [15:0] ctrl_word_out;
    wire fb_clk;
    wire [6:0] N_div;
    wire lock;
    wire dco_clk_out; 

    // Instantiate DUT
    adpll_top dut (
        .ref_clk(ref_clk),
        .clk_fast(clk_fast), 
        .rst(rst),
        .N_int(N_int),
        .K_mod(K_mod),
        .phase_residual(phase_residual),
        .ctrl_word_out(ctrl_word_out),
        .fb_clk(fb_clk),
        .N_div(N_div),
        .lock(lock),
        .dco_clk_out(dco_clk_out),

        .fifo_wr_en(fifo_wr_en),
        .fifo_data_in(fifo_data_in),
        .fifo_full(fifo_full),
        .fifo_rd_en(fifo_rd_en),
        .fifo_data_out(fifo_data_out),
        .fifo_empty(fifo_empty)
    );

    // Clock Generation
    initial begin
        ref_clk = 0;
        forever #250 ref_clk = ~ref_clk; // 2 MHz Reference Clock
    end
    
    initial begin
        clk_fast = 0;
        forever #1 clk_fast = ~clk_fast; // 500 MHz Fast Clock
    end

    
    // VCD waveform logging
    initial begin
        $dumpfile("cdc_waveform.vcd");
        $dumpvars(0, tb_cdc_fifo);
    end

    // Parameters for testing
    localparam TEST_PACKETS = 10000;
    
    integer packets_sent = 0;
    integer packets_received = 0;
    integer expected_data = 1;
    integer errors = 0;


    // Thread 1: Writer (ref_clk domain)
    initial begin
        fifo_wr_en = 0;
        fifo_data_in = 0;
        rst = 1;
        #1000 rst = 0;

        $display("Starting CDC FIFO test: Writing %0d packets from ref_clk domain...", TEST_PACKETS);
        
        while (packets_sent < TEST_PACKETS) begin
            @(negedge ref_clk);
            
            if (!fifo_full) begin 
                fifo_wr_en = 1;
                fifo_data_in = packets_sent + 1; 
                packets_sent = packets_sent + 1;
            end else begin
                fifo_wr_en = 0;
            end
        end
        
        @(negedge ref_clk) fifo_wr_en = 0;
        $display("Finished writing packets.");
    end

    
    // Thread 2: Reader (dco_clk_out domain)
    initial begin
        fifo_rd_en = 0;
        @(negedge rst);
        
        // waveform demonstration stall
        wait(fifo_full == 1'b1);
        #2000; 
        

        while (packets_received < TEST_PACKETS) begin
            @(negedge dco_clk_out);
            
            if (!fifo_empty) begin
                fifo_rd_en = 1;
                
                if (fifo_data_out !== expected_data) begin
                    $display("ERROR at packet %0d: Expected %0d, Got %0d", 
                              packets_received, expected_data, fifo_data_out);
                    errors = errors + 1;
                end
                expected_data = expected_data + 1;
                packets_received = packets_received + 1;
                
                if (packets_received % 2000 == 0) begin
                    $display("Progress: Successfully crossed %0d packets.", packets_received);
                end
            end else begin
                fifo_rd_en = 0;
            end
        end
        
        $display("=======================================");
        $display("CDC FIFO Test Complete!");
        $display("Total Errors     : %0d", errors);
        $display("=======================================");
        
        $finish;
    end
endmodule
