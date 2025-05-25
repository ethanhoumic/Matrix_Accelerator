`timescale 1 ns/1 ps
`include "int8_mac.v"
`include "int4_mac.v"
`include "vsq_support.v"
`include "mac16.v"


module tb;

    reg clk;
    reg rst_n;
    reg [4223:0] a_vec;
    reg [263:0] b_vec;
    reg is_int8_mode;
    reg is_int4_mode;
    reg is_vsq;
    reg valid;
    reg [383:0] partial_sum_in;

    wire [383:0] partial_sum_out;
    wire mac_done_wire;
    wire ppu_wire;

    mac_16 #(
        .CALC_BIT_WIDTH(1),     // for testing purposes
        .CALC_COUNT(1)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .a_vec(a_vec),
        .b_vec(b_vec),
        .is_int8_mode(is_int8_mode),
        .is_int4_mode(is_int4_mode),
        .is_vsq(is_vsq),
        .valid(valid),
        .partial_sum_in(partial_sum_in),
        .partial_sum_out(partial_sum_out),
        .mac_done_wire(mac_done_wire),
        .calc_done_wire(ppu_wire)
    );

    always #5 clk = ~clk;
    integer i;
    
    initial begin

        $fsdbDumpfile("simulation.fsdb");
        $fsdbDumpvars(0, tb);

        clk = 0;
        rst_n = 0;
        a_vec = 0;
        b_vec = 0;
        is_int8_mode = 0;
        is_int4_mode = 0;
        is_vsq = 0;
        valid = 0;
        partial_sum_in = 0;

        #5;
        rst_n = 1;
        for (i = 0; i < 16; i = i + 1) begin
            a_vec[i * 264 + 263 -: 264] = {8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 
                8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 
                8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 
                8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'b0};
        end
        b_vec = {8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 
            8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 
            8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 
            8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'd4, 8'b0};
        valid = 1;
        is_int8_mode = 1;
        partial_sum_in = {24'd4, 24'd4, 24'd4, 24'd4, 24'd4, 24'd4, 24'd4, 
            24'd4, 24'd4, 24'd4, 24'd4, 24'd4, 24'd4, 24'd4, 24'd4, 24'd4};
        #100;
        $finish;

    end

    always @(posedge clk or negedge rst_n) begin
        if (mac_done_wire) begin
            $display("Partial sum out: %h", partial_sum_out);
            $finish;
        end
    end    

endmodule