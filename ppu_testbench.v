`timescale 1ns/1ps
`include "ppu.v"

module tb;

    integer i;

    reg clk;
    reg rst_n;
    reg [383:0] partial_sum;
    reg [7:0] scale;
    reg [7:0] bias;
    reg done;
    reg valid;
    wire [639:0] scaled_sum_wire;
    wire [127:0] output_data;
    wire [17:0] reciprocal_wire;
    wire [17:0] vec_max;
    wire [135:0] quantized_data_wire;

    ppu uut(
        .clk(clk),
        .rst_n(rst_n),
        .partial_sum(partial_sum),
        .scale(scale),
        .bias(bias),
        .valid(valid),
        .scaled_sum_wire(scaled_sum_wire),
        .vec_max_wire(vec_max),
        .reciprocal_wire(reciprocal_wire),
        .quantized_data_wire(quantized_data_wire),
        .output_data(output_data),
        .done_wire(done)
    );

    always #5 clk = ~clk;

    initial begin

        $fsdbDumpfile("simulation.fsdb");
        $fsdbDumpvars(0, tb);

        clk = 0;
        rst_n = 0;
        partial_sum = 0;
        scale = 0;
        bias = 0;
        valid = 0;


        #10;

        /* Input datas in mac are (70, 80) * (40, 90),
           so the quantized data in sram should be (6, 7) * (3, 7),
           the per vector scale factor is 11.42857 and 12.85714
           and second quantization yields gamma = 0.101237 = 0x1d in fp8,
           so the scales are 113 and 127. 
           Hence, in sram, the data should be (6, 7, 113) and (3, 7, 127), while gamma = 0x1d
           The output of mac should be (6 * 3 + 7 * 7) * 113 * 127 = 961517,
           and the scale is 0x1d. */
        rst_n = 1;
        partial_sum = {16{24'd961517}};
        scale = 8'h1d;
        bias = 8'd1;
        valid = 1;

        $display("partial_sum = %d", partial_sum[23:0]);
        $display("scale = %b", scale);
        $display("bias = %b", bias);

        #50;
        valid = 0;

    end

    always @(posedge clk) begin
        if (done) begin
            $display("The scaled sum is %d", scaled_sum_wire[39:0]);
            $display("The maximal element is %b", vec_max);
            $display("The per vector scale factor is %b", reciprocal_wire);
            $display("The quantized data is %b", quantized_data_wire);
            $display("The output data is %b", output_data);
            $finish;
        end
    end

    
endmodule