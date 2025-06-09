`timescale 1 ns/1 ps

`ifndef INT8_MAC
`define INT8_MAC

module int8_mac (
    input  wire                int8_en,
    input  wire        [263:0] a_vec,
    input  wire        [263:0] b_vec,
    input  wire signed [23:0]  partial_sum_in,
    output wire signed [23:0]  partial_sum_out
);

    wire signed [7:0] a [0:32];
    wire signed [7:0] b [0:32];
    wire signed [23:0] mult_sum;

    genvar j;
    generate
        for (j = 0; j < 33; j = j + 1) begin : UNPACK
            assign a[j] = $signed(a_vec[(j * 8) +: 8]);
            assign b[j] = $signed(b_vec[(j * 8) +: 8]);
        end
    endgenerate

    // reduction: dot product
    wire signed [23:0] products [1:32];

    generate
        for (j = 1; j <= 32; j = j + 1) begin : MULTIPLY
            assign products[j] = a[j] * b[j];
        end
    endgenerate

    wire signed [23:0] dot_sum_lvl1 [0:15];
    wire signed [23:0] dot_sum_lvl2 [0:7];
    wire signed [23:0] dot_sum_lvl3 [0:3];
    wire signed [23:0] dot_sum_lvl4 [0:1];
    wire signed [23:0] dot_sum_final;

    generate
        for (j = 0; j < 16; j = j + 1)
            assign dot_sum_lvl1[j] = products[2*j+1] + products[2*j+2];

        for (j = 0; j < 8; j = j + 1)
            assign dot_sum_lvl2[j] = dot_sum_lvl1[2*j] + dot_sum_lvl1[2*j+1];

        for (j = 0; j < 4; j = j + 1)
            assign dot_sum_lvl3[j] = dot_sum_lvl2[2*j] + dot_sum_lvl2[2*j+1];

        for (j = 0; j < 2; j = j + 1)
            assign dot_sum_lvl4[j] = dot_sum_lvl3[2*j] + dot_sum_lvl3[2*j+1];
    endgenerate

    assign dot_sum_final = dot_sum_lvl4[0] + dot_sum_lvl4[1];

    assign partial_sum_out = int8_en ? (partial_sum_in + dot_sum_final) : 24'sd0;

endmodule

`endif