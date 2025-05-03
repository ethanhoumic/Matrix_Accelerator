`timescale 1 ns/1 ps
`include "int8_mac.v"
`include "int4_mac.v"
`include "mac16.v"
`define PATTERN_A "a_sram_binary.txt"
`define PATTERN_B "b_sram_binary.txt"
`define PATTERN_OUTPUT "output_sram_binary.txt"
`define PATTERN_HARDWARE "latch_array_output.txt"

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

    integer i, j, k, error;
    reg [263:0] a_buffer [0:2047];   // 16 banks 
    reg [263:0] b_buffer [0:2047];   // single bank
    reg [383:0] output_buffer [0:15];

    always #5 clk = ~clk;

    initial begin

        integer fd;
        fd = $fopen(`PATTERN_HARDWARE, "w");

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

        $readmemb(`PATTERN_A, a_buffer);
        $readmemb(`PATTERN_B, b_buffer);
        $readmemb(`PATTERN_OUTPUT, output_buffer);

        #5;
        rst_n = 1;
        is_int8_mode = 1;
        is_int4_mode = 0;
        is_vsq = 0;

        for (i = 0; i < 128; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                @(posedge clk) b_vec = b_buffer[i * 16 + j];
                if (j == 0) begin
                    for (k = 0; k < 16; k = k + 1) begin
                        a_vec[k * 264 + 263 -: 264] = a_buffer[i * 16 + k];
                    end
                end
            end
        end

        #100;

        for (i = 0; i < 16; i = i + 1) begin
            if (latch_array_out[i * 384 +: 384] !== output_buffer[i]) begin
                error = error + 1;
                $display("Error at index %d: Expected %b, got %b", i, output_buffer[i], latch_array_out[i * 384 +: 384]);
            end else begin
                $display("Correct at index %d: Expected %b, got %b", i, output_buffer[i], latch_array_out[i * 384 +: 384]);
            end
            $fdisplay(fd, "%b", latch_array_out[i * 384 +: 384]);
        end
        
        $fclose(fd);
        if (error == 0) begin
            $display("All tests passed!");
        end else begin
            $display("%d errors found!", error);
        end
        #100;

        $finish;

    end

endmodule