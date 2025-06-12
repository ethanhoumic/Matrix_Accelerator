`timescale 1 ns/1 ps
`include "mac16.v"
`include "ppu.v"
`ifndef MATRIX_ACCELERATOR
`define MATRIX_ACCELERATOR

module matrix_accelerator #(
    parameter CALC_BIT_WIDTH = 5,    // Width of the counter
    parameter CALC_COUNT     = 32    // Number of cycles for the calculation
) (
    input  wire          clk,
    input  wire          rst_n,
    input  wire [4223:0] a_vec,
    input  wire [263:0]  b_vec,
    input  wire          is_int8_mode,
    input  wire          is_int4_mode,
    input  wire          is_vsq,
    input  wire          valid_mac,
    input  wire [7:0]    scale_a,
    input  wire [7:0]    scale_w,
    input  wire [7:0]    bias,
    input  wire          valid_ppu,
    output wire [639:0]  scaled_sum_wire,
    output wire [15:0]   vec_max_wire,
    output wire [15:0]   reciprocal_wire,
    output wire [135:0]  quantized_data_wire,
    output wire [127:0]  softmax_out,
    output wire          done_wire
);

    wire         mac_done_wire;
    wire         acc_done_wire;
    wire         ppu;
    wire         stall;
    wire [383:0] to_ppu_wire;
    wire [383:0] partial_sum_in;
    wire [383:0] partial_sum_out;

    mac_16 mac_inst (
        .clk(clk),
        .rst_n(rst_n),
        .a_vec(a_vec),
        .b_vec(b_vec),
        .is_int8_mode(is_int8_mode),
        .is_int4_mode(is_int4_mode),
        .is_vsq(is_vsq),
        .valid(valid_mac),
        .partial_sum_in(partial_sum_in),
        .stall(stall),
        .partial_sum_out(partial_sum_out),
        .mac_done_wire(mac_done_wire),
        .calc_done_wire(ppu)
    );

    acc_collector acc_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(valid_mac),
        .ppu(ppu),
        .mac_done(mac_done_wire),
        .partial_sum_in(partial_sum_out),
        .to_mac(partial_sum_in),
        .to_ppu(to_ppu_wire),
        .done_wire(acc_done_wire)
    );

    ppu ppu_inst (
        .clk(clk),
        .rst_n(rst_n),
        .partial_sum(to_ppu_wire),
        .scale_a(scale_a),
        .scale_w(scale_w),
        .bias(bias),
        .valid(ppu && valid_ppu),
        .scaled_sum_wire(scaled_sum_wire),
        .vec_max_wire(vec_max_wire),
        .reciprocal_wire(reciprocal_wire),
        .quantized_data_wire(quantized_data_wire),
        .output_data(softmax_out),
        .done_wire(done_wire)
    );

    
endmodule

`endif