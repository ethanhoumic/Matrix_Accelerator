`timescale 1 ns/1 ps
`include "int8_mac.v"
`include "int4_mac.v"
`include "mac16.v"
`define PATTERN_A "a_sram_binary.txt"
`define PATTERN_B "b_sram_binary.txt"
`define PATTERN_OUTPUT "output_sram_binary.txt"

module tb;
    reg clk;
    reg rst_n;
    reg [4223:0] a_vec;
    reg [263:0] b_vec;
    reg is_int8_mode;
    reg is_int4_mode;
    reg is_vsq;
    wire [6143:0] latch_array_out;

    mac_16 uut (
        .clk(clk),
        .rst_n(rst_n),
        .a_vec(a_vec),
        .b_vec(b_vec),
        .is_int8_mode(is_int8_mode),
        .is_int4_mode(is_int4_mode),
        .is_vsq(is_vsq),
        .latch_array_out(latch_array_out)
    );

    integer i, j, k;
    reg [263:0] a_buffer [0:2047];   // 16 banks 
    reg [263:0] b_buffer [0:2047];   // single bank
    reg [383:0] output_buffer [0:2047];
    reg [7:0] error;
    reg [15:0] check_count;

    always #5 clk = ~clk;

    initial begin
        $fsdbDumpfile("simulation.fsdb");
        $fsdbDumpvars(0, tb);

        // Initialize signals
        clk = 0;
        rst_n = 0;
        is_int8_mode = 0;
        is_int4_mode = 0;
        is_vsq = 0;
        a_vec = 0;
        b_vec = 0;
        error = 0;
        check_count = 0;

        // Read test vectors
        $readmemb(`PATTERN_A, a_buffer);
        $readmemb(`PATTERN_B, b_buffer);
        $readmemb(`PATTERN_OUTPUT, output_buffer);

        // Reset sequence
        #20;
        rst_n = 1;
        #10;
        is_int8_mode = 1;
        
        // Load a_vec one time
        for (k = 0; k < 16; k = k + 1) begin
            a_vec[k * 264 + 263 -: 264] = a_buffer[k];
        end

        // Process each batch
        for (i = 0; i < 128; i = i + 1) begin
            // Process 16 b vectors
            for (j = 0; j < 16; j = j + 1) begin
                b_vec = b_buffer[i * 16 + j];
                #10; // Wait for one clock cycle
            end

            // Allow MAC unit to complete additional cycles for accumulation
            #80;
            
            // Verify results
            $display("Checking batch %d", i);
            for (k = 0; k < 16; k = k + 1) begin
                if (latch_array_out[k * 384 +: 384] !== output_buffer[i*16+k]) begin
                    error = error + 1;
                    $display("Error at index %d: Expected %h, got %h", i*16+k, output_buffer[i*16+k], latch_array_out[k * 384 +: 384]);
                end else begin
                    check_count = check_count + 1;
                    $display("Correct at index %d", i*16+k);
                end
            end
            
            // Reset for next batch
            #10;
            rst_n = 0;
            #20;
            rst_n = 1;
            #10;

            // Load next batch of a vectors
            for (k = 0; k < 16; k = k + 1) begin
                a_vec[k * 264 + 263 -: 264] = a_buffer[(i+1) * 16 + k];
            end
        end

        #100;
        $display("Test completed with %d errors and %d correct checks", error, check_count);
        $finish;
    end
endmodule