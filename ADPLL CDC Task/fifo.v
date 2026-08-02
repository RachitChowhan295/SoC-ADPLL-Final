`timescale 1ns/1ps

module async_fifo #(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 4
)(
    input  wire                  wr_clk,
    input  wire                  wr_rst,
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] data_in,
    output wire                  full,

    input  wire                  rd_clk,
    input  wire                  rd_rst,
    input  wire                  rd_en,
    output wire [DATA_WIDTH-1:0] data_out,
    output wire                  empty
);

    reg [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

    // Binary and Gray pointers
    reg [ADDR_WIDTH:0] wr_ptr_bin, wr_ptr_gray;
    reg [ADDR_WIDTH:0] rd_ptr_bin, rd_ptr_gray;

    // Synchronizers
    (* ASYNC_REG = "TRUE" *) reg [ADDR_WIDTH:0] wr_ptr_gray_sync1, wr_ptr_gray_sync2;
    (* ASYNC_REG = "TRUE" *) reg [ADDR_WIDTH:0] rd_ptr_gray_sync1, rd_ptr_gray_sync2;

    // ---------------------------------------------------------
    // Write Domain Logic
    // ---------------------------------------------------------
    wire [ADDR_WIDTH:0] wr_ptr_bin_next = wr_ptr_bin + (wr_en & ~full);
    wire [ADDR_WIDTH:0] wr_ptr_gray_next = (wr_ptr_bin_next >> 1) ^ wr_ptr_bin_next;
    
    assign full = (wr_ptr_gray == {~rd_ptr_gray_sync2[ADDR_WIDTH:ADDR_WIDTH-1], 
                                    rd_ptr_gray_sync2[ADDR_WIDTH-2:0]});

    always @(posedge wr_clk or posedge wr_rst) begin
        if (wr_rst) begin
            wr_ptr_bin  <= 0;
            wr_ptr_gray <= 0;
        end else begin
            wr_ptr_bin  <= wr_ptr_bin_next;
            wr_ptr_gray <= wr_ptr_gray_next;
            if (wr_en && !full) begin
                mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= data_in;
            end
        end
    end

    always @(posedge wr_clk or posedge wr_rst) begin
        if (wr_rst) begin
            rd_ptr_gray_sync1 <= 0;
            rd_ptr_gray_sync2 <= 0;
        end else begin
            rd_ptr_gray_sync1 <= rd_ptr_gray;
            rd_ptr_gray_sync2 <= rd_ptr_gray_sync1;
        end
    end

    // ---------------------------------------------------------
    // Read Domain Logic
    // ---------------------------------------------------------
    wire [ADDR_WIDTH:0] rd_ptr_bin_next = rd_ptr_bin + (rd_en & ~empty);
    wire [ADDR_WIDTH:0] rd_ptr_gray_next = (rd_ptr_bin_next >> 1) ^ rd_ptr_bin_next;
    
    assign empty = (rd_ptr_gray == wr_ptr_gray_sync2);
    assign data_out = mem[rd_ptr_bin[ADDR_WIDTH-1:0]];

    always @(posedge rd_clk or posedge rd_rst) begin
        if (rd_rst) begin
            rd_ptr_bin  <= 0;
            rd_ptr_gray <= 0;
        end else begin
            rd_ptr_bin  <= rd_ptr_bin_next;
            rd_ptr_gray <= rd_ptr_gray_next;
        end
    end

    always @(posedge rd_clk or posedge rd_rst) begin
        if (rd_rst) begin
            wr_ptr_gray_sync1 <= 0;
            wr_ptr_gray_sync2 <= 0;
        end else begin
            wr_ptr_gray_sync1 <= wr_ptr_gray;
            wr_ptr_gray_sync2 <= wr_ptr_gray_sync1;
        end
    end

endmodule