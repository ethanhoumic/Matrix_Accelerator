`timescale 1ns/ 1ps
`ifndef VSQ_SUPPORT
`define VSQ_SUPPORT

module vsq_support (
    input wire is_vsq,
    input wire [7:0] a_factor,
    input wire [7:0] b_factor,
    input wire [13:0] partial_sum_in,
    output reg [23:0] partial_sum_out
);
;
    wire s_b = b_vec[7:0] & is_vsq;
    wire [7:0] s_product = (a_factor * s_b) & 8'hFF; // Mask to 8 bits
    wire [21:0] scaled_product = (partial_sum_in * s_product) & 22'h3FFFFF; // Mask to 22 bits

    partial_sum_out = (partial_sum_in & is_vsq) + scaled_product;
    
endmodule

`endif