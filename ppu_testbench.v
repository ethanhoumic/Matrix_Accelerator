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
    wire [17:0] vec_max;

    ppu uut(
        .clk(clk),
        .rst_n(rst_n),
        .partial_sum(partial_sum),
        .scale(scale),
        .bias(bias),
        .valid(1'b1),
        .vec_max_wire(vec_max),
        .latch_done(done)
        //.output_data(output_data),
        //.done(done)
    );

    always #5 clk = ~clk;

    initial begin

        $fsdbDumpfile("simulation.fsdb");
        $fsdbDumpvars(0, tb);

        clk = 0;
        rst_n = 10;
        partial_sum = 0;
        scale = 0;
        bias = 0;

        #10;

        rst_n = 1;
        partial_sum = {24'b110000000000000000000000, {8{24'b100000000000000000000000}}, 24'b111110000000000000000000, {5{24'b100000000000000000000000}}, 24'b111000000000000000000000};
        scale = 8'd16;
        bias = 8'd1;

        $display("partial_sum = %b", partial_sum);
        $display("scale = %b", scale);
        $display("bias = %b", bias);

    end

    always @(posedge clk) begin
        if (done) begin
            $display("The maximal element is %b", vec_max);
            $finish;
        end
    end

    
endmodule