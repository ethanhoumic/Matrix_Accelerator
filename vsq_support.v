`timescale 1ns/ 1ps
`ifndef VSQ_SUPPORT
`define VSQ_SUPPORT

module vsq_support (
    input  wire        is_vsq,
    input  wire [7:0]  a_factor,
    input  wire [7:0]  b_factor,
    input  wire [13:0] from_int4,
    input  wire [23:0] partial_sum_in,
    output wire [23:0] partial_sum_out
);

    wire [7:0] s_b = is_vsq ? b_factor : 8'h00; // Select b_factor if is_vsq is true, else 0
    wire [7:0] s_product = (a_factor * s_b) & 8'hFF; // Mask to 8 bits
    wire [21:0] mul_result = from_int4 * s_product; // Multiply from_int4 with the scaled product
    wire [23:0] product = partial_sum_in + mul_result;

    assign partial_sum_out = is_vsq ? product : 384'b0;
    
endmodule

`endif