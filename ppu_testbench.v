`timescale 1ns/1ps
`include "ppu.v"

module tb;

    integer i;

    reg clk;
    reg rst_n;
    reg [383:0] partial_sum;
    reg [7:0] scale;
    reg [7:0] bias;
    reg [3:0] write_addr;
    reg [295:0] output_data [0:15];
    reg done;
    wire [295:0] from_latch_array;

    ppu uut(
        .clk(clk),
        .rst_n(rst_n),
        .partial_sum(partial_sum),
        .scale(scale),
        .bias(bias),
        .valid(1'b1),
        .from_latch_array(from_latch_array),
        .read_en(done)
        //.output_data(output_data),
        //.done(done)
    );

    always #5 clk = ~clk;

    initial begin

        clk = 0;
        rst_n = 10;
        partial_sum = 0;
        scale = 0;
        bias = 0;
        for (i = 0; i < 16; i = i + 1) begin
            output_data[i] = 0;
        end
        write_addr <= 0;

        #10;

        rst_n = 1;
        partial_sum = {16{24'b100000000000000000000000}};
        scale = 8'd16;
        bias = 8'd1;

        $display("partial_sum = %b", partial_sum);
        $display("scale = %b", scale);
        $display("bias = %b", bias);

    end

    always @(posedge clk) begin
        if (done) begin
            output_data[write_addr] <= from_latch_array;
            $display("write_addr = %d", write_addr);
            $display("from_latch_array = %b", from_latch_array);
            if (write_addr == 15) begin
                $display("All data written to output_data.");
                $finish;
            end
            else begin
                write_addr <= write_addr + 1;
            end
        end
    end

    
endmodule