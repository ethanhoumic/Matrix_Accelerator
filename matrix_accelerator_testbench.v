`timescale 1ns/1ps
`include "matrix_accelerator.v"
`define PATTERN_A "a_sram_binary.txt"
`define PATTERN_B "b_sram_binary.txt"
`define HEIGHT 32

module tb;

    integer i;

    reg clk;
    reg rst_n;
    reg [4223:0] a_vec;
    reg [263:0] b_vec;
    reg is_int8_mode;
    reg is_int4_mode;
    reg is_vsq;
    reg [4:0] addr;
    reg [4:0] cycle_cnt;
    reg valid_mac;

    reg [7:0] scale;
    reg [7:0] bias;
    reg done;
    reg valid_ppu;
    wire [639:0] scaled_sum_wire;
    wire [127:0] output_data;
    wire [15:0] reciprocal_wire;
    wire [15:0] vec_max;
    wire [135:0] quantized_data_wire;

    matrix_accelerator #(
        .CALC_BIT_WIDTH(5),    // Width of the counter
        .CALC_COUNT(32)        // Number of cycles for the calculation
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .a_vec(a_vec),
        .b_vec(b_vec),
        .is_int8_mode(is_int8_mode),
        .is_int4_mode(is_int4_mode),
        .is_vsq(is_vsq),
        .valid_mac(valid_mac),
        .scale(scale),
        .bias(bias),
        .valid_ppu(valid_ppu),
        .scaled_sum_wire(scaled_sum_wire),
        .vec_max_wire(vec_max),
        .reciprocal_wire(reciprocal_wire),
        .quantized_data_wire(quantized_data_wire),
        .softmax_out(output_data),
        .done_wire(done)
    );

    reg [263:0] a_buffer [0:`HEIGHT-1];
    reg [263:0] b_buffer [0:`HEIGHT-1];

    always #5 clk = ~clk;

    initial begin

        $fsdbDumpfile("simulation_2.fsdb");
        $fsdbDumpvars(0, tb);

        clk = 0;
        rst_n = 0;
        a_vec = 0;
        b_vec = 0;
        is_int8_mode = 0;
        is_int4_mode = 0;
        is_vsq = 0;
        valid_mac = 0;
        addr = 0;
        cycle_cnt = 0;
        valid_ppu = 0;
        scale = 0;
        bias = 0;

        $readmemb(`PATTERN_A, a_buffer);
        $readmemb(`PATTERN_B, b_buffer);

        for (i = 0; i < `HEIGHT + 1; i = i + 1) begin
            $display("The %dth input value of a_buffer is %d", i, a_buffer[0][i * 8 +: 8]);
        end

        #10;

        /* Input datas in mac are (4900, 5600) * (2800, 6300) and (42000, 49000) * (3500, 5600),
           so the quantized data in sram should be (6, 7) * (3, 7) and (6, 7) * (4, 7),
           the per vector scale factor are (800, 900) and (7000, 800)
           and second quantization yields gamma = 55.11811024 = 0x65 in fp8,
           so the scales are (14, 16) and (127, 14). 
           Hence, in sram, the data should be (6, 7, 14) * (3, 7, 16) and (6, 7, 127) * (4, 7, 14), while gamma = 0x65
           The output of mac should be (6 * 3 + 7 * 7) * 14 * 16 = 15008 and (6 * 4 + 7 * 7) * 127 * 14 = 129794,
           and the scale is 0x4e. */
        rst_n = 1;
        is_int8_mode = 1;
        scale = 8'h65;
        bias = 8'd1;
        valid_mac = 1;
        valid_ppu = 1;

        $display("scale = %d", scale);
        $display("bias = %d", bias);

        #650;
        valid_ppu = 0;

        #1000;
        $finish;

    end

    always @(posedge clk) begin
        if (done) begin
            for (i = 0; i < 16; i = i + 1) begin
                $display("The %dth scaled sum is %d", i, scaled_sum_wire[i * 40 +: 40]);
            end
            $display("The maximal element is %d", vec_max);
            $display("The per vector scale factor is %d", reciprocal_wire);
            for (i = 0; i < 16; i = i + 1) begin
                $display("The %dth quantized data is %d", i, quantized_data_wire[i * 8 +: 8]);
            end
            for (i = 0; i < 16; i = i + 1) begin
                $display("The %dth softmax data is %d", i, output_data[i*8 +: 8]);
            end
            $finish;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_cnt <= 0;
            a_vec <= 0;
            b_vec <= 0;
        end 
        else begin
            if (valid_mac) begin
                b_vec <= b_buffer[cycle_cnt];
                if (cycle_cnt % 16 == 0) begin
                    a_vec <= {
                        a_buffer[cycle_cnt],
                        a_buffer[cycle_cnt + 1],
                        a_buffer[cycle_cnt + 2],
                        a_buffer[cycle_cnt + 3],
                        a_buffer[cycle_cnt + 4],
                        a_buffer[cycle_cnt + 5],
                        a_buffer[cycle_cnt + 6],
                        a_buffer[cycle_cnt + 7],
                        a_buffer[cycle_cnt + 8],
                        a_buffer[cycle_cnt + 9],
                        a_buffer[cycle_cnt + 10],
                        a_buffer[cycle_cnt + 11],
                        a_buffer[cycle_cnt + 12],
                        a_buffer[cycle_cnt + 13],
                        a_buffer[cycle_cnt + 14],
                        a_buffer[cycle_cnt + 15]
                    };
                end
                cycle_cnt <= cycle_cnt + 1;
            end
        end
    end

endmodule