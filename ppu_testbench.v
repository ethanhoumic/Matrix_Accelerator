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

        rst_n = 1;
        partial_sum = {24'b011000000000000000000000, {8{24'b010000000000000000000000}}, 24'b011111000000000000000000, {5{24'b010000000000000000000000}}, 24'b011100000000000000000000};
        scale = 8'd16;
        bias = 8'd1;
        valid = 1;

        $display("partial_sum = %b", partial_sum);
        $display("scale = %b", scale);
        $display("bias = %b", bias);

        #50;
        valid = 0;

    end

    always @(posedge clk) begin
        if (done) begin
            $display("The maximal element is %b", vec_max);
            $display("The per vector scale factor is %b", reciprocal_wire);
            $display("The quantized data is %b", quantized_data_wire);
            $display("The output data is %b", output_data);
            $finish;
        end
    end

    
endmodule